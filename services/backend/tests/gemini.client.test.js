const {
  toAnalyzeShape,
  normalizeMaterial,
  inferMaterialFromMessage,
  parseWeightKgFromMessage,
  buildCopilotFallback,
  finalizeCopilotResult,
} = require("../src/clients/gemini.client");

describe("gemini.client mapping", () => {
  test("maps a 9V battery onto Batteries, not books", () => {
    const raw = toAnalyzeShape(
      {
        material: "battery",
        electronic_device: "9V battery",
        short_description: "Transistor radio 9V cell.",
        confidence: 0.9,
        suggested_condition: "average",
        estimated_weight_kg: 0.05,
      },
      null
    );

    expect(raw.category_id).toBe("battery");
    expect(raw.category).toBe("Batteries");
    expect(raw.electronic_device).toContain("9V");
    expect(raw.critical_mineral).toBe(true);
  });

  test("maps a blue converter board onto pcb, not lcd_panel", () => {
    expect(normalizeMaterial("circuit board")).toBe("pcb");
    const raw = toAnalyzeShape({ material: "pcb", confidence: 0.88 }, null);
    expect(raw.category_id).toBe("pcb_motherboard");
    expect(raw.category).toBe("Motherboard / PCB");
  });

  test("copilot infers silver + weight from user text, not copper wire", () => {
    expect(inferMaterialFromMessage("5 killo silver I have").id).toBe("silver");
    expect(parseWeightKgFromMessage("5 killo silver I have")).toBe(5);

    const fallback = buildCopilotFallback({
      message: "5 killo silver I have",
      language: "en",
    });
    expect(fallback.detected_material).toBe("silver");
    expect(fallback.category_name).toBe("Silver Scrap");
    expect(fallback.estimated_weight_kg).toBe(5);
    expect(fallback.suggested_rate_per_kg).toBe(80000);
    expect(fallback.total_estimated_value_inr).toBe(400000);
    expect(fallback.best_paying_recycler.name).toMatch(/Precious/i);

    const fixed = finalizeCopilotResult(
      {
        reply: "Copper wire at 650",
        detected_material: "copper_wire",
        category_name: "Copper Wire",
        estimated_weight_kg: 5,
        suggested_rate_per_kg: 650,
        total_estimated_value_inr: 3250,
        best_paying_recycler: {
          name: "Vidyut High-Grade Copper Refiners",
          rate_per_kg: 650,
          distance_km: 3.5,
          address: "Marketyard, Pune",
        },
        suggested_actions: ["Create Lot"],
        can_create_lot: true,
      },
      { message: "5 killo silver I have", language: "en" }
    );
    expect(fixed.detected_material).toBe("silver");
    expect(fixed.category_name).toBe("Silver Scrap");
    expect(fixed.suggested_rate_per_kg).toBe(80000);
    expect(fixed.total_estimated_value_inr).toBe(400000);
    expect(fixed.reply.toLowerCase()).toContain("silver");
    expect(fixed.reply.toLowerCase()).not.toContain("copper wire");
  });

  test("copilot strips invented copper valuation for chit-chat", () => {
    const fixed = finalizeCopilotResult(
      {
        reply: "For your scrap, Vidyut pays ₹650/kg for copper wire.",
        detected_material: "copper_wire",
        category_name: "Copper Wire",
        estimated_weight_kg: 5,
        suggested_rate_per_kg: 650,
        total_estimated_value_inr: 3250,
        best_paying_recycler: {
          name: "Vidyut High-Grade Copper Refiners",
          rate_per_kg: 650,
        },
        suggested_actions: ["Create Lot"],
        can_create_lot: true,
      },
      { message: "love you", language: "en" }
    );
    expect(fixed.detected_material).toBeNull();
    expect(fixed.total_estimated_value_inr).toBeNull();
    expect(fixed.can_create_lot).toBe(false);
    expect(fixed.reply).toContain("Vidyut");
  });
});
