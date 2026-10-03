/*
|--------------------------------------------------------------------------
| LOYALTY STORE UNIT TESTS
|--------------------------------------------------------------------------
| Threshold (≥5 → favorite/regular), one-time referral credits, reminder
| cooldown. No Express / PostgreSQL required.
|--------------------------------------------------------------------------
*/

const store = require("../../src/modules/loyalty/loyalty.store");

describe("loyalty.store", () => {
  beforeEach(() => {
    store.resetForTests();
  });

  test("becomes favorite and regular at 5 completed purchases", () => {
    const userId = "user-1";
    const collectorId = "collector-1";

    for (let i = 1; i <= 4; i += 1) {
      const { pair, becameRegular } = store.recordPurchase({
        userId,
        collectorId,
        requestId: `req_${i}`,
        amount: 100,
        userName: "Ananya",
      });
      expect(pair.completedCount).toBe(i);
      expect(pair.isFavorite).toBe(false);
      expect(pair.isRegular).toBe(false);
      expect(becameRegular).toBe(false);
    }

    const fifth = store.recordPurchase({
      userId,
      collectorId,
      requestId: "req_5",
      amount: 100,
      userName: "Ananya",
    });
    expect(fifth.pair.completedCount).toBe(5);
    expect(fifth.pair.isFavorite).toBe(true);
    expect(fifth.pair.isRegular).toBe(true);
    expect(fifth.becameRegular).toBe(true);

    const me = store.listForUser(userId);
    expect(me.favorites).toHaveLength(1);
    expect(me.favorites[0].collectorId).toBe(collectorId);

    const collectorNotifs = store.getNotifications(collectorId);
    expect(collectorNotifs.some((n) => n.type === "REGULAR_CUSTOMER")).toBe(true);
  });

  test("purchase is idempotent on requestId", () => {
    store.recordPurchase({
      userId: "u1",
      collectorId: "c1",
      requestId: "same",
      amount: 50,
    });
    const again = store.recordPurchase({
      userId: "u1",
      collectorId: "c1",
      requestId: "same",
      amount: 50,
    });
    expect(again.duplicate).toBe(true);
    expect(again.pair.completedCount).toBe(1);
  });

  test("referral awards ₹20 each once after first purchase", () => {
    const referrer = "ref-user";
    const newbie = "new-user";
    store.ensureProfile(referrer, { fullName: "Referrer" });
    store.ensureProfile(newbie, { fullName: "Newbie" });

    const code = store.listForUser(referrer).profile.referralCode;
    const applied = store.applyReferralCode(newbie, code);
    expect(applied.ok).toBe(true);

    const first = store.recordPurchase({
      userId: newbie,
      collectorId: "c1",
      requestId: "first_deal",
      amount: 200,
    });
    expect(first.referralAwarded).toBe(true);

    const referrerProfile = store.listForUser(referrer).profile;
    const newbieProfile = store.listForUser(newbie).profile;
    expect(referrerProfile.creditsBalance).toBe(store.REFERRAL_CREDIT_INR);
    expect(newbieProfile.creditsBalance).toBe(store.REFERRAL_CREDIT_INR);

    const second = store.recordPurchase({
      userId: newbie,
      collectorId: "c1",
      requestId: "second_deal",
      amount: 200,
    });
    expect(second.referralAwarded).toBe(false);
    expect(store.listForUser(referrer).profile.creditsBalance).toBe(
      store.REFERRAL_CREDIT_INR
    );
  });

  test("cannot apply own referral code", () => {
    store.ensureProfile("self", { fullName: "Self" });
    const code = store.listForUser("self").profile.referralCode;
    const result = store.applyReferralCode("self", code);
    expect(result.ok).toBe(false);
  });

  test("reminder cooldown blocks a second send within 6 days", () => {
    store.recordPurchase({
      userId: "cust",
      collectorId: "kab",
      requestId: "p1",
      userName: "Cust",
    });

    const first = store.sendReminder({
      collectorId: "kab",
      userId: "cust",
      cadence: "WEEK",
    });
    expect(first.ok).toBe(true);

    const userNotifs = store.getNotifications("cust");
    expect(userNotifs[0].type).toBe("SCRAP_REMINDER");
    expect(userNotifs[0].bodyEn).toMatch(/raddi|paper|scrap/i);

    const second = store.sendReminder({
      collectorId: "kab",
      userId: "cust",
      cadence: "MONTH",
    });
    expect(second.ok).toBe(false);
    expect(second.status).toBe(429);
  });

  test("suggestedCadence is WEEK after 7 inactive days", () => {
    store.recordPurchase({
      userId: "cust2",
      collectorId: "kab2",
      requestId: "old",
      userName: "Old",
    });
    const pair = store.getPair("cust2", "kab2");
    // Force last purchase 10 days ago via upsert through another purchase rewrite:
    // use internal map by recording then manually patching via re-upsert.
    store.recordPurchase({
      userId: "cust2",
      collectorId: "kab2",
      requestId: "old2",
      userName: "Old",
    });
    // Directly adjust lastPurchaseAt on the stored pair for inactivity math.
    const keyPair = store.getPair("cust2", "kab2");
    keyPair.lastPurchaseAt = new Date(
      Date.now() - 10 * 24 * 60 * 60 * 1000
    ).toISOString();

    const customers = store.listCustomersForCollector("kab2");
    expect(customers[0].suggestedCadence).toBe("WEEK");
    expect(customers[0].daysInactive).toBeGreaterThanOrEqual(10);
  });
});
