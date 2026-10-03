/*
|--------------------------------------------------------------------------
| NOTIFICATIONS SERVICE
|--------------------------------------------------------------------------
| Notification business rules and localisation.
|
| The collector app renders English, Hindi and Marathi (see
| apps/collector/lib/l10n/app_*.arb), so a notification carries the English
| text as authoritative and Hindi/Marathi as optional overlays. A missing
| translation falls back to English rather than rendering an empty bubble.
|--------------------------------------------------------------------------
*/

const repository = require("./notifications.repository");
const logger = require("../../lib/logger");
const { NotFoundError } = require("../../lib/errors");

/**
 * Minimal en -> hi / mr wording for the events the backend raises itself.
 * Field-collected translations belong in the mobile app; these cover the
 * server-generated copy only.
 */
const COPY = {
  HANDOVER_CONFIRMED: {
    titleHi: "✓ माल हस्तांतरण निश्चित",
    titleMr: "✓ माल हस्तांतरण निश्चित",
    bodyHi: "आपके भंडारण की हस्तांतरण प्रक्रिया पूरी हो गई है।",
    bodyMr: "तुमच्या साठ्याची हस्तांतरण प्रक्रिया पूर्ण झाली आहे.",
  },
  PRICE_ALERT: {
    titleHi: "🔔 भाव इशारा",
    titleMr: "🔔 दर इशारा",
    bodyHi: "आपके चयनित सामग्री का भाव आपकी अपेक्षा पर पहुंच गया है।",
    bodyMr: "तुम्ही निवडलेल्या साहित्याचा दर तुमच्या अपेक्षेपर्यंत पोहोचला आहे.",
  },
  LOT_STATUS: {
    titleHi: "स्थिति अपडेट",
    titleMr: "स्थिती अपडेट",
    bodyHi: "आपके भंडारण की स्थिति बदल गई है।",
    bodyMr: "तुमच्या साठ्याची स्थिती बदलली आहे.",
  },
  EPR: {
    titleHi: "ईपीआर अपडेट",
    titleMr: "ईपीआर अपडेट",
    bodyHi: "ईपीआर से जुड़ी नई जानकारी उपलब्ध है।",
    bodyMr: "ईपीआरशी संबंधित नवीन माहिती उपलब्ध आहे.",
  },
  SYSTEM: {
    titleHi: "सूचना",
    titleMr: "सूचना",
    bodyHi: "आपके खाते से जुड़ी एक सूचना है।",
    bodyMr: "तुमच्या खात्याशी संबंधित एक सूचना आहे.",
  },
};

async function create({ userId, lotId = null, type, titleEn, bodyEn, ...rest }) {
  const copy = COPY[type] || {};

  const notification = await repository.create({
    userId,
    lotId,
    type,
    titleEn,
    bodyEn,
    titleHi: rest.titleHi ?? copy.titleHi ?? null,
    titleMr: rest.titleMr ?? copy.titleMr ?? null,
    bodyHi: rest.bodyHi ?? copy.bodyHi ?? null,
    bodyMr: rest.bodyMr ?? copy.bodyMr ?? null,
  });

  logger.info("Notification created", {
    notificationId: notification.id,
    type,
    lotId,
  });

  return notification;
}

/**
 * Insert several notifications in one round trip.
 *
 * Used where one domain event fans out to many recipients — a rate update
 * that triggers several collectors' price alerts. Without this, N matching
 * alerts would mean N separate INSERT round trips inside the request.
 */
async function createMany(items) {
  if (!Array.isArray(items) || items.length === 0) {
    return [];
  }

  const withCopy = items.map((item) => {
    const copy = COPY[item.type] || {};

    return {
      ...item,
      lotId: item.lotId ?? null,
      titleHi: item.titleHi ?? copy.titleHi ?? null,
      titleMr: item.titleMr ?? copy.titleMr ?? null,
      bodyHi: item.bodyHi ?? copy.bodyHi ?? null,
      bodyMr: item.bodyMr ?? copy.bodyMr ?? null,
    };
  });

  const created = await repository.createMany(withCopy);

  logger.info("Notifications created", {
    count: created.length,
    types: [...new Set(withCopy.map((item) => item.type))],
  });

  return created;
}

async function list(userId, options) {
  const [rows, total, unread] = await Promise.all([
    repository.listForUser(userId, options),
    repository.countForUser(userId),
    repository.countForUser(userId, { unreadOnly: true }),
  ]);

  return {
    notifications: rows.map(repository.toNotification),
    meta: {
      ...options,
      total,
      unreadCount: unread,
    },
  };
}

async function markRead(userId, publicId) {
  const updated = await repository.markRead(userId, publicId);

  if (!updated) {
    throw new NotFoundError("Notification not found");
  }

  return updated;
}

async function markAllRead(userId) {
  const count = await repository.markAllRead(userId);

  return { updated: count };
}

module.exports = {
  create,
  createMany,
  list,
  markRead,
  markAllRead,
};