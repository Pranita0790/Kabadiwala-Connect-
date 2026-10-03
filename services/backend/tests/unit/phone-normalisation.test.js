/*
|--------------------------------------------------------------------------
| INDIAN PHONE NORMALISATION
|--------------------------------------------------------------------------
| `normalisePhone` in src/modules/auth/auth.schema.js keys every collector
| account on the E.164 string it returns.
|
| It is now the only thing standing between a Firebase-asserted
| `phone_number` claim and a new platform account, because the token's phone
| claim never passes through the zod `phonePattern` — Firebase states the
| number is genuine, not that it is an Indian mobile.
|
| apps/collector/lib/services/firebase_auth_service.dart mirrors these rules
| in Dart (`normaliseIndianPhone`). If the app and the backend disagree on a
| single input, a collector who signs in twice ends up with two accounts and
| their lots split between them. Every case here has a twin in
| apps/collector/test/phone_number_normalisation_test.dart — change one side,
| change both.
|--------------------------------------------------------------------------
*/

const { normalisePhone, isIndianMobile, phonePattern } = require("../../src/modules/auth/auth.schema");

describe("normalisePhone", () => {
  describe("accepts real Indian mobile numbers", () => {
    const accepted = {
      "9876543210": "+919876543210",
      "+919876543210": "+919876543210",
      "919876543210": "+919876543210",
      "09876543210": "+919876543210",
      "+91 98765 43210": "+919876543210",
      "98765 43210": "+919876543210",
      "98765-43210": "+919876543210",
      "+91-98765-43210": "+919876543210",
      "  9876543210  ": "+919876543210",
      // Indian mobile numbers start 6-9.
      "6123456789": "+916123456789",
      "7123456789": "+917123456789",
      "8123456789": "+918123456789",
      "9123456789": "+919123456789",
    };

    for (const [input, expected] of Object.entries(accepted)) {
      it(`normalises ${JSON.stringify(input)} to ${expected}`, () => {
        expect(normalisePhone(input)).toBe(expected);
        expect(isIndianMobile(expected)).toBe(true);
      });
    }
  });

  describe("rejects everything else", () => {
    const rejected = [
      "",
      "   ",
      "abc",
      "12345",
      "98765", // too short
      "98765432101", // 11 digits, no leading 0
      "987654321012", // 12 digits, does not start 91
      "+14155552671", // US
      "+972501234567", // Israel
      "+447911123456", // UK
      "+9876543210", // +91 but only 9 national digits
      "+91987654321001", // too long
      "+1 415 555 2671", // US, spaced
      "4155552671", // US national number with no country code
      "0987654321", // 10 digits starting 0
      "+0919876543210", // +09 is not a country code
      "0000000000",
      "1111111111", // Indian range starts at 6
    ];

    for (const input of rejected) {
      it(`rejects ${JSON.stringify(input)}`, () => {
        expect(normalisePhone(input)).toBeNull();
      });
    }

    it("does not throw on a non-string", () => {
      expect(() => normalisePhone(null)).not.toThrow();
      expect(normalisePhone(null)).toBeNull();
      expect(normalisePhone(undefined)).toBeNull();
      expect(normalisePhone({})).toBeNull();
      expect(normalisePhone([])).toBeNull();
    });

    it("coerces a numeric input rather than throwing", () => {
      // A text controller always yields a String, so this is defensive only.
      // The important part is that it cannot be made to crash.
      expect(normalisePhone(9876543210)).toBe("+919876543210");
    });
  });

  describe("idempotence", () => {
    it("normalising an already-normalised number is a no-op", () => {
      const once = "+919876543210";

      expect(normalisePhone(once)).toBe(once);
      expect(normalisePhone(normalisePhone(once))).toBe(once);
    });
  });

  describe("agreement with the zod phonePattern", () => {
    /*
     | The zod layer runs only on collector-typed input. The normaliser also
     | sees Firebase's claim, which zod never sees. These assert the two do
     | not disagree about what an Indian mobile number is — otherwise a
     | number can pass signup validation and then be refused at sign-in.
     */
    const zodAccepted = [
      "9876543210",
      "09876543210",
      "919876543210",
      "+919876543210",
      "+91 98765 43210",
      "6123456789",
    ];

    for (const input of zodAccepted) {
      it(`zod and the normaliser agree on ${JSON.stringify(input)}`, () => {
        expect(phonePattern.test(input)).toBe(true);
        expect(normalisePhone(input)).not.toBeNull();
      });
    }

    it("both reject a foreign number", () => {
      expect(phonePattern.test("+14155552671")).toBe(false);
      expect(normalisePhone("+14155552671")).toBeNull();
    });
  });
});