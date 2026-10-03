const { toAnalyzeShape, normalizeMaterial } = require("../src/clients/gemini.client");

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
});
