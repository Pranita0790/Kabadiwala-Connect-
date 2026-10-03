/*
|--------------------------------------------------------------------------
| MATERIALS + RATES INTEGRATION
|--------------------------------------------------------------------------
| Verifies the catalogue ids and the rate card actually line up, and that
| the indicative-value calculation uses seeded data rather than the values
| the caller submitted.
|
| This is where the AI service's snake_case MaterialName literals meet the
| database catalogue, so the id spellings are asserted explicitly.
|--------------------------------------------------------------------------
*/

const {
  describeIntegration,
  resetDb,
  teardown,
} = require("../helpers/db");

const materialsRepository = require("../../src/modules/materials/materials.repository");
const materialsService = require("../../src/modules/materials/materials.service");
const ratesService = require("../../src/modules/rates/rates.service");
const {
  deployedModel,
  CRITICAL_MINERAL_POTENTIAL_MESSAGE,
} = require("../../src/config/constants");

describeIntegration("materials + rates", () => {
  beforeAll(async () => {
    await resetDb();
  });

  afterAll(teardown);

  describe("catalogue ids", () => {
    it("uses the exact MaterialName literals the AI service emits", async () => {
      const materials = await materialsRepository.list();
      const ids = materials.map((material) => material.id);

      // Every class the deployed model can predict must exist in the
      // catalogue under its AI spelling, including underscores.
      for (const supported of deployedModel.supportedMaterials) {
        expect(ids).toContain(supported);
      }

      expect(ids).toEqual(
        expect.arrayContaining([
          "pcb",
          "battery",
          "crt",
          "lcd_panel",
          "cable",
        ])
      );
    });

    it("does not use kebab-case ids", async () => {
      const materials = await materialsRepository.list();

      for (const material of materials) {
        expect(material.id).not.toMatch(/-/);
      }
    });

    it("marks only the model-supported classes as supported", async () => {
      const supported = await materialsRepository.list({ modelSupportedOnly: true });

      expect(supported.map((material) => material.id).sort()).toEqual(
        [...deployedModel.supportedMaterials].sort()
      );
    });

    it("finds a material by its AI spelling", async () => {
      const material = await materialsRepository.findById("lcd_panel");

      expect(material).not.toBeNull();
      expect(material.displayName).toBe("LCD Panel");
    });

    it("returns null for a material that is not in the catalogue", async () => {
      expect(await materialsRepository.findById("lcd-panel")).toBeNull();
      expect(await materialsRepository.findById("unobtainium")).toBeNull();
    });
  });

  describe("model capabilities", () => {
    it("reports the deployed model version and threshold", async () => {
      const capabilities = await materialsService.modelCapabilities();

      expect(capabilities.modelVersion).toBe(deployedModel.modelVersion);
      expect(capabilities.confidenceThreshold).toBe(
        deployedModel.confidenceThreshold
      );
    });

    it("lists catalogue-only materials separately", async () => {
      const capabilities = await materialsService.modelCapabilities();

      expect(capabilities.catalogueOnlyMaterials).toEqual(
        expect.arrayContaining(["motor", "mixed_plastics"])
      );
      expect(capabilities.catalogueOnlyMaterials).not.toContain("pcb");
    });
  });

  describe("indicative value", () => {
    it("derives the value from the rate card, ignoring client estimates", async () => {
      const estimate = await ratesService.calculateIndicativeValue({
        materialId: "pcb",
        weightKg: 2,
        region: "IN-MH",
      });

      expect(estimate.estimatedValue).toBeGreaterThan(0);
      expect(estimate.ratePerKg).toBeGreaterThan(0);

      // Rate * weight, allowing for rounding in the stored rate.
      expect(estimate.estimatedValue).toBeCloseTo(estimate.ratePerKg * 2, 1);
    });

    it("returns a null value with a reason when no rate is on the board", async () => {
      const estimate = await ratesService.calculateIndicativeValue({
        materialId: "motor",
        weightKg: 3,
        region: "IN-XX",
      });

      expect(estimate.estimatedValue).toBeNull();
    });
  });

  describe("critical mineral wording", () => {
    it("never states a photograph proves composition", async () => {
      const materials = await materialsRepository.list();
      const critical = materials.filter((material) => material.isCriticalMineral);

      expect(critical.length).toBeGreaterThan(0);

      for (const material of critical) {
        expect(material.criticalMineralReason).toMatch(
          /inference, not laboratory analysis/i
        );
      }
    });

    it("keeps the critical-mineral wording as a shared constant", () => {
      // AGENTS.md section 7 requires "potential ... detected" wording rather
      // than a claim that a photograph proves composition.
      expect(CRITICAL_MINERAL_POTENTIAL_MESSAGE).toMatch(/potential/i);
      expect(CRITICAL_MINERAL_POTENTIAL_MESSAGE).not.toMatch(
        /proves|confirmed|contains/i
      );
    });
  });
});