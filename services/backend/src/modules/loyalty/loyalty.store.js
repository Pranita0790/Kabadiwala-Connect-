/*
|--------------------------------------------------------------------------
| LOYALTY STORE (in-memory)
|--------------------------------------------------------------------------
| Favorite kabadiwala (≥5 purchases), regular customer, inactivity
| reminders, and ₹20/₹20 referral credits. Pure functions so Jest can
| cover thresholds without Express or PostgreSQL.
|--------------------------------------------------------------------------
*/

const THRESHOLD = 5;
const REFERRAL_CREDIT_INR = 20;
const REMINDER_COOLDOWN_MS = 6 * 24 * 60 * 60 * 1000; // 6 days

/** @type {Map<string, object>} key = `${userId}::${collectorId}` */
const pairs = new Map();
/** @type {Map<string, object>} key = userPublicId */
const profiles = new Map();
/** @type {Map<string, string>} referralCode -> userPublicId */
const referralCodes = new Map();
/** @type {Map<string, object>} pending referral by referred userPublicId */
const pendingReferrals = new Map();
/** @type {string[]} processed requestIds (idempotent purchase) */
const processedRequests = new Set();
/** @type {Map<string, object[]>} in-app notifications by userPublicId */
const notifications = new Map();
/** @type {Map<string, string>} reminder cooldown key `${collectorId}::${userId}` -> ISO */
const reminderSentAt = new Map();

function pairKey(userId, collectorId) {
  return `${userId}::${collectorId}`;
}

function ensureProfile(userPublicId, { fullName = null, phone = null } = {}) {
  let profile = profiles.get(userPublicId);
  if (!profile) {
    const code = makeReferralCode(userPublicId);
    profile = {
      userId: userPublicId,
      fullName: fullName || "Customer",
      phone: phone || "",
      referralCode: code,
      creditsBalance: 0,
      ledger: [],
      referredBy: null,
      referralAwarded: false,
    };
    profiles.set(userPublicId, profile);
    referralCodes.set(code, userPublicId);
  } else {
    if (fullName) profile.fullName = fullName;
    if (phone) profile.phone = phone;
  }
  return profile;
}

function makeReferralCode(userPublicId) {
  const raw = String(userPublicId).replace(/-/g, "").toUpperCase();
  const suffix = raw.slice(-4) || "USER";
  let code = `KC-${suffix}`;
  let n = 0;
  while (referralCodes.has(code) && referralCodes.get(code) !== userPublicId) {
    n += 1;
    code = `KC-${suffix}${n}`;
  }
  return code;
}

function getPair(userId, collectorId) {
  return pairs.get(pairKey(userId, collectorId)) || null;
}

function upsertPair(userId, collectorId, patch = {}) {
  const key = pairKey(userId, collectorId);
  const existing = pairs.get(key) || {
    userId,
    collectorId,
    chooseCount: 0,
    completedCount: 0,
    isFavorite: false,
    isRegular: false,
    lastPurchaseAt: null,
    lastChooseAt: null,
    userName: null,
    userPhone: null,
  };
  const next = { ...existing, ...patch };
  if (next.completedCount >= THRESHOLD) {
    next.isFavorite = true;
    next.isRegular = true;
  }
  pairs.set(key, next);
  return next;
}

function pushNotification(userPublicId, notification) {
  const list = notifications.get(userPublicId) || [];
  list.unshift(notification);
  notifications.set(userPublicId, list.slice(0, 100));
}

function credit(userPublicId, amount, reason, meta = {}) {
  const profile = ensureProfile(userPublicId);
  profile.creditsBalance = Number(profile.creditsBalance || 0) + amount;
  profile.ledger.unshift({
    id: `led_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    amount,
    reason,
    createdAt: new Date().toISOString(),
    ...meta,
  });
  return profile;
}

function recordChoose(userId, collectorId) {
  const pair = upsertPair(userId, collectorId, {
    chooseCount: (getPair(userId, collectorId)?.chooseCount || 0) + 1,
    lastChooseAt: new Date().toISOString(),
  });
  return pair;
}

/**
 * Record a completed purchase. Idempotent on requestId.
 * @returns {{ pair, becameRegular, referralAwarded, duplicate }}
 */
function recordPurchase({
  userId,
  collectorId,
  requestId,
  amount = 0,
  userName = null,
  userPhone = null,
}) {
  if (requestId && processedRequests.has(String(requestId))) {
    return {
      pair: getPair(userId, collectorId),
      becameRegular: false,
      referralAwarded: false,
      duplicate: true,
    };
  }
  if (requestId) processedRequests.add(String(requestId));

  ensureProfile(userId, { fullName: userName, phone: userPhone });
  const before = getPair(userId, collectorId);
  const wasRegular = Boolean(before?.isRegular);
  const nextCount = (before?.completedCount || 0) + 1;

  const pair = upsertPair(userId, collectorId, {
    completedCount: nextCount,
    lastPurchaseAt: new Date().toISOString(),
    userName: userName || before?.userName || null,
    userPhone: userPhone || before?.userPhone || null,
  });

  const becameRegular = !wasRegular && pair.isRegular;
  if (becameRegular) {
    pushNotification(collectorId, {
      id: `loy_reg_${Date.now()}`,
      type: "REGULAR_CUSTOMER",
      titleEn: "Regular customer",
      bodyEn: `${pair.userName || "A customer"} is now your regular customer (${THRESHOLD}+ pickups).`,
      titleHi: "रेगुलर ग्राहक",
      bodyHi: `${pair.userName || "एक ग्राहक"} अब आपके रेगुलर ग्राहक बन गए हैं (${THRESHOLD}+ पिकअप)।`,
      userId: pair.userId,
      collectorId,
      createdAt: new Date().toISOString(),
      isRead: false,
    });
  }

  let referralAwarded = false;
  const profile = profiles.get(userId);
  if (profile && profile.referredBy && !profile.referralAwarded) {
    credit(profile.referredBy, REFERRAL_CREDIT_INR, "REFERRAL_REWARD", {
      referredUserId: userId,
    });
    credit(userId, REFERRAL_CREDIT_INR, "REFERRAL_WELCOME", {
      referrerUserId: profile.referredBy,
    });
    profile.referralAwarded = true;
    pendingReferrals.delete(userId);
    referralAwarded = true;

    pushNotification(profile.referredBy, {
      id: `loy_ref_${Date.now()}`,
      type: "REFERRAL_EARN",
      titleEn: "Referral earned ₹20",
      bodyEn: "Your friend completed their first scrap deal. ₹20 credit added.",
      titleHi: "रेफरल से ₹20 मिले",
      bodyHi: "आपके दोस्त ने पहला स्क्रैप डील पूरा किया। ₹20 क्रेडिट जुड़ गया।",
      createdAt: new Date().toISOString(),
      isRead: false,
    });
  }

  return { pair, becameRegular, referralAwarded, duplicate: false };
}

function applyReferralCode(userId, code) {
  const normalized = String(code || "")
    .trim()
    .toUpperCase();
  if (!normalized) {
    return { ok: false, error: "Referral code required" };
  }
  const referrerId = referralCodes.get(normalized);
  if (!referrerId) {
    return { ok: false, error: "Invalid referral code" };
  }
  if (referrerId === userId) {
    return { ok: false, error: "Cannot use your own referral code" };
  }
  const profile = ensureProfile(userId);
  if (profile.referredBy || profile.referralAwarded) {
    return { ok: false, error: "Referral already applied" };
  }
  profile.referredBy = referrerId;
  pendingReferrals.set(userId, {
    referrerId,
    code: normalized,
    appliedAt: new Date().toISOString(),
  });
  return { ok: true, referrerId, code: normalized };
}

function listForUser(userId) {
  const profile = ensureProfile(userId);
  const relations = Array.from(pairs.values()).filter((p) => p.userId === userId);
  const favorites = relations.filter((p) => p.isFavorite);
  return {
    profile: {
      userId: profile.userId,
      referralCode: profile.referralCode,
      creditsBalance: profile.creditsBalance,
      referredBy: profile.referredBy,
      referralAwarded: profile.referralAwarded,
      ledger: profile.ledger,
    },
    relations,
    favorites,
    notifications: notifications.get(userId) || [],
  };
}

function listCustomersForCollector(collectorId) {
  const now = Date.now();
  return Array.from(pairs.values())
    .filter((p) => p.collectorId === collectorId && p.completedCount > 0)
    .map((p) => {
      const last = p.lastPurchaseAt ? new Date(p.lastPurchaseAt).getTime() : null;
      const daysInactive = last ? Math.floor((now - last) / (24 * 60 * 60 * 1000)) : null;
      let suggestedCadence = null;
      if (daysInactive != null && daysInactive >= 30) suggestedCadence = "MONTH";
      else if (daysInactive != null && daysInactive >= 7) suggestedCadence = "WEEK";
      const cooldownKey = `${collectorId}::${p.userId}`;
      const lastReminder = reminderSentAt.get(cooldownKey) || null;
      return {
        ...p,
        daysInactive,
        suggestedCadence,
        lastReminderAt: lastReminder,
      };
    })
    .sort((a, b) => (b.completedCount || 0) - (a.completedCount || 0));
}

function sendReminder({ collectorId, userId, cadence = "WEEK", collectorName = "Kabadiwala" }) {
  const pair = getPair(userId, collectorId);
  if (!pair || pair.completedCount < 1) {
    return { ok: false, error: "Customer not found for this collector", status: 404 };
  }
  const cooldownKey = `${collectorId}::${userId}`;
  const prev = reminderSentAt.get(cooldownKey);
  if (prev && Date.now() - new Date(prev).getTime() < REMINDER_COOLDOWN_MS) {
    return { ok: false, error: "Reminder cooldown active (wait 6 days)", status: 429 };
  }

  const isMonth = String(cadence).toUpperCase() === "MONTH";
  const titleEn = isMonth ? "Monthly scrap reminder" : "Weekly scrap reminder";
  const bodyEn = isMonth
    ? "1 mahina ho gaya — scrap/raddi ready ho to batayein."
    : "1 week ho gaya — koi raddi, paper ya scrap nahi aaya. Pickup chahiye?";
  const titleHi = isMonth ? "मासिक स्क्रैप रिमाइंडर" : "साप्ताहिक स्क्रैप रिमाइंडर";
  const bodyHi = isMonth
    ? "1 महीना हो गया — स्क्रैप/रद्दी तैयार हो तो बताएं।"
    : "1 हफ्ता हो गया — कोई रद्दी, पेपर या स्क्रैप नहीं आया। पिकअप चाहिए?";

  const notification = {
    id: `loy_rem_${Date.now()}`,
    type: "SCRAP_REMINDER",
    titleEn,
    bodyEn,
    titleHi,
    bodyHi,
    collectorId,
    collectorName,
    cadence: isMonth ? "MONTH" : "WEEK",
    createdAt: new Date().toISOString(),
    isRead: false,
  };
  pushNotification(userId, notification);
  reminderSentAt.set(cooldownKey, notification.createdAt);

  pushNotification(collectorId, {
    id: `loy_rem_ack_${Date.now()}`,
    type: "REMINDER_SENT",
    titleEn: "Reminder sent",
    bodyEn: `Reminder sent to ${pair.userName || "customer"}.`,
    titleHi: "रिमाइंडर भेजा गया",
    bodyHi: `${pair.userName || "ग्राहक"} को रिमाइंडर भेज दिया गया।`,
    userId,
    createdAt: new Date().toISOString(),
    isRead: false,
  });

  return { ok: true, notification };
}

function getNotifications(userPublicId) {
  return notifications.get(userPublicId) || [];
}

function markNotificationRead(userPublicId, id) {
  const list = notifications.get(userPublicId) || [];
  const next = list.map((n) => (n.id === id ? { ...n, isRead: true } : n));
  notifications.set(userPublicId, next);
  return next.find((n) => n.id === id) || null;
}

/** Test helper — wipe all in-memory state. */
function resetForTests() {
  pairs.clear();
  profiles.clear();
  referralCodes.clear();
  pendingReferrals.clear();
  processedRequests.clear();
  notifications.clear();
  reminderSentAt.clear();
}

module.exports = {
  THRESHOLD,
  REFERRAL_CREDIT_INR,
  REMINDER_COOLDOWN_MS,
  ensureProfile,
  recordChoose,
  recordPurchase,
  applyReferralCode,
  listForUser,
  listCustomersForCollector,
  sendReminder,
  getNotifications,
  markNotificationRead,
  getPair,
  resetForTests,
};
