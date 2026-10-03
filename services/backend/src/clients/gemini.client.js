/*
|--------------------------------------------------------------------------
| GEMINI CLIENT
|--------------------------------------------------------------------------
| Vision + JSON classification for collector photos. The API key lives in
| process env only (AGENTS.md section 9). Flutter never calls Gemini.
|--------------------------------------------------------------------------
*/

const axios = require("axios");

const config = require("../config/env");
const logger = require("../lib/logger");
const {
  CRITICAL_MINERAL_POTENTIAL_MESSAGE,
} = require("../config/constants");
const {
  UpstreamTimeoutError,
  UpstreamUnavailableError,
  UnprocessableError,
} = require("../lib/errors");

const SUPPORTED_MATERIALS = [
  "pcb",
  "battery",
  "cable",
  "crt",
  "lcd_panel",
  "motor",
  "magnet_bearing_assembly",
  "mixed_plastics",
  "paper",
  "book",
  "unknown",
];

const CATEGORY_BY_MATERIAL = {
  pcb: { category_id: "pcb_motherboard", category: "Motherboard / PCB" },
  battery: { category_id: "battery", category: "Batteries" },
  cable: { category_id: "copper_wire", category: "Copper Wire" },
  crt: { category_id: "display_monitor", category: "Monitors & Displays" },
  lcd_panel: { category_id: "display_monitor", category: "Monitors & Displays" },
  motor: { category_id: "heavy_appliances", category: "Heavy Electricals" },
  magnet_bearing_assembly: {
    category_id: "heavy_appliances",
    category: "Heavy Electricals",
  },
  mixed_plastics: { category_id: "plastic", category: "Plastic" },
  paper: { category_id: "paper", category: "Paper" },
  book: { category_id: "book", category: "Books" },
  unknown: { category_id: "mixed_ewaste", category: "Mixed E-Waste" },
};

const TYPICAL_WEIGHT_KG = {
  pcb: 1.5,
  battery: 0.5,
  cable: 5.0,
  crt: 12.0,
  lcd_panel: 8.0,
  motor: 15.0,
  magnet_bearing_assembly: 10.0,
  mixed_plastics: 4.0,
  paper: 2.0,
  book: 3.0,
  unknown: 5.0,
};

const ANALYZE_PROMPT = `You identify scrap and e-waste photos for Kabadiwala Connect collectors in India.
Return JSON only with these keys:
- material: one of pcb, battery, cable, crt, lcd_panel, motor, mixed_plastics, paper, book, unknown
- electronic_device: short object name (e.g. "9V battery", "buck converter PCB")
- short_description: one factual sentence
- confidence: number 0 to 1
- suggested_condition: good, average, or scrap
- estimated_weight_kg: typical lot weight for this item
- suggestions: array of 3 short tips for the collector (handling, category, next step)

Rules:
- A 9V / AA / AAA / pack cell is battery, never book or paper.
- A blue or green circuit board, converter, or motherboard is pcb, never lcd_panel.
- A TV, monitor, or laptop screen is lcd_panel or crt.
- Bound books are book. Loose sheets are paper.
- Visual inference only, not laboratory proof of composition.
- Tips must be practical for informal collectors in India.`;

function isConfigured() {
  return Boolean(config.ai.geminiApiKey);
}

function stripFences(text) {
  if (typeof text !== "string") return "";
  return text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}

function normalizeMaterial(value) {
  const key = String(value || "unknown")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  if (SUPPORTED_MATERIALS.includes(key)) return key;
  if (key.includes("pcb") || key.includes("motherboard") || key.includes("board")) {
    return "pcb";
  }
  if (key.includes("battery")) return "battery";
  if (key.includes("cable") || key.includes("wire") || key.includes("copper")) {
    return "cable";
  }
  if (key.includes("lcd") || key.includes("monitor") || key.includes("display")) {
    return "lcd_panel";
  }
  if (key.includes("book")) return "book";
  if (key.includes("paper")) return "paper";
  if (key.includes("plastic")) return "mixed_plastics";
  if (key.includes("motor") || key.includes("appliance")) return "motor";
  return "unknown";
}

function toAnalyzeShape(parsed, weightKg) {
  const material = normalizeMaterial(parsed?.material);
  const lot = CATEGORY_BY_MATERIAL[material] || CATEGORY_BY_MATERIAL.unknown;
  const confidence = Math.min(
    1,
    Math.max(0, Number(parsed?.confidence) || 0.7)
  );
  const estimated =
    Number(parsed?.estimated_weight_kg) > 0
      ? Number(parsed.estimated_weight_kg)
      : TYPICAL_WEIGHT_KG[material] || 5;
  const resolvedWeight =
    typeof weightKg === "number" && weightKg > 0 ? weightKg : estimated;
  const critical = material === "pcb" || material === "battery";
  const condition = ["good", "average", "scrap"].includes(
    parsed?.suggested_condition
  )
    ? parsed.suggested_condition
    : "average";

  const suggestions = normalizeSuggestions(parsed?.suggestions, material);

  return {
    material,
    confidence,
    category: lot.category,
    category_id: lot.category_id,
    electronic_device: String(
      parsed?.electronic_device || lot.category
    ).slice(0, 80),
    short_description: String(
      parsed?.short_description || `Best match is ${lot.category}.`
    ).slice(0, 240),
    critical_mineral: critical,
    critical_mineral_reason: critical
      ? CRITICAL_MINERAL_POTENTIAL_MESSAGE
      : null,
    model_version: `gemini:${config.ai.geminiModel}`,
    rule_version: "gemini-lot-categories-1",
    supported_materials: SUPPORTED_MATERIALS.filter((name) => name !== "unknown"),
    weight_estimate: {
      estimated_weight_kg: resolvedWeight,
      confidence: 0.6,
      method: typeof weightKg === "number" ? "user_provided" : "typical_lot",
    },
    value_estimate: {
      estimated_value_inr: null,
      confidence: 0.4,
      rate_per_kg_inr: null,
      method: "rate_card_pending",
    },
    suggested_condition: condition,
    suggestions,
  };
}

function normalizeSuggestions(raw, material) {
  const fromModel = Array.isArray(raw)
    ? raw
        .map((item) => String(item || "").trim())
        .filter((item) => item.length > 0)
        .slice(0, 4)
    : [];
  if (fromModel.length >= 2) return fromModel;
  return defaultSuggestions(material);
}

function defaultSuggestions(material) {
  switch (material) {
    case "battery":
      return [
        "Tape the terminals and keep cells dry.",
        "Save this lot as Batteries, not mixed scrap.",
        "Hand over to an authorized e-waste recycler.",
      ];
    case "pcb":
      return [
        "This looks like a circuit board / converter module.",
        "Save as Motherboard / PCB for a better rate.",
        "Do not smash boards — keep them intact for the recycler.",
      ];
    case "cable":
      return [
        "Bundle copper wire separately from plastic.",
        "Save as Copper Wire on the lot form.",
        "Ask the recycler for copper rate, not mixed e-waste.",
      ];
    case "lcd_panel":
    case "crt":
      return [
        "Handle screens carefully — glass can break.",
        "Save as Monitors & Displays.",
        "CRTs are heavy; confirm weight before handover.",
      ];
    case "paper":
    case "book":
      return [
        "Keep dry recyclables away from e-waste.",
        "Books and paper fetch a different rate than electronics.",
      ];
    default:
      return [
        "If unsure, choose Mixed E-Waste and add a photo note.",
        "An authorized recycler can re-check the category at handover.",
      ];
  }
}

async function analyzeImage({ fileBuffer, mimetype, weightKg }) {
  if (!isConfigured()) {
    throw new UpstreamUnavailableError("Gemini API key is not configured.");
  }

  const started = Date.now();
  const mime = (mimetype || "image/jpeg").toLowerCase();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    config.ai.geminiModel
  )}:generateContent`;

  let response;
  try {
    response = await axios.post(
      url,
      {
        contents: [
          {
            parts: [
              { text: ANALYZE_PROMPT },
              {
                inlineData: {
                  mimeType: mime.startsWith("image/") ? mime : "image/jpeg",
                  data: fileBuffer.toString("base64"),
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: "application/json",
        },
      },
      {
        params: { key: config.ai.geminiApiKey },
        timeout: config.ai.timeoutMs,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    if (error.code === "ECONNABORTED" || error.code === "ETIMEDOUT") {
      throw new UpstreamTimeoutError("Gemini timed out.");
    }
    const status = error.response?.status;
    if (status === 400 || status === 422) {
      throw new UnprocessableError("Gemini rejected the image.");
    }
    logger.warn("Gemini analyze failed", { message: error.message, status });
    throw new UpstreamUnavailableError("Gemini is unavailable.");
  }

  const text = response.data?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text)
    .filter(Boolean)
    .join("\n");

  let parsed;
  try {
    parsed = JSON.parse(stripFences(text));
  } catch {
    throw new UnprocessableError("Gemini returned a non-JSON body.");
  }

  return {
    raw: toAnalyzeShape(parsed, weightKg),
    latencyMs: Date.now() - started,
  };
}

module.exports = {
  isConfigured,
  analyzeImage,
  toAnalyzeShape,
  normalizeMaterial,
};
