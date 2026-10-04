/*
|--------------------------------------------------------------------------
| NVIDIA NIM AI CLIENT
|--------------------------------------------------------------------------
| High-performance Llama-3.2 Vision & Mistral/DeepSeek/Nemotron inference
| via NVIDIA NIM (https://integrate.api.nvidia.com/v1)
|--------------------------------------------------------------------------
*/

const axios = require("axios");
const logger = require("../lib/logger");

const NVIDIA_API_KEY =
  process.env.NVIDIA_API_KEY ||
  "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";

const NIM_MODELS = [
  "meta/llama-3.2-11b-vision-instruct",
];

const TOP_RECYCLERS = [
  { name: "Vidyut High-Grade Copper Refiners", category: "Non-Ferrous Metals", best_for: ["cable", "copper_wire", "non_ferrous", "brass"], rate_per_kg: 650, distance_km: 3.5, address: "Marketyard, Pune" },
  { name: "Florus Recycling Pvt. Ltd. (MPCB 14,500 MT/A)", category: "E-Waste", best_for: ["pcb", "e_waste", "display", "appliances"], rate_per_kg: 580, distance_km: 4.2, address: "Wadhu Khurd, Haveli, Pune" },
  { name: "Mahalaxmi E-Waste Dismantlers & Smelters", category: "E-Waste", best_for: ["pcb", "battery", "e_waste"], rate_per_kg: 520, distance_km: 5.1, address: "Ramtekdi Hadapsar, Pune" },
  { name: "Eco-Recycling Ltd. (Ecoreco Vasai)", category: "Lithium & E-Waste", best_for: ["battery", "e_waste", "pcb"], rate_per_kg: 560, distance_km: 14.5, address: "Sheetal Ind Park, Vasai, Palghar" },
  { name: "Chloride Metal Ltd. (MPCB 72,000 MT/A)", category: "Battery Waste", best_for: ["battery", "lead_acid"], rate_per_kg: 105, distance_km: 12.8, address: "Markal, Khed, Pune" },
  { name: "Agarwal Plastics Pvt. Ltd.", category: "Plastic Waste", best_for: ["mixed_plastics", "plastic", "pet"], rate_per_kg: 55, distance_km: 4.1, address: "Kudalwadi, Chikhali, Pune" },
  { name: "Indrayani Ferrocast Pvt. Ltd.", category: "Ferrous & Steel", best_for: ["ferrous", "iron", "steel"], rate_per_kg: 46, distance_km: 13.5, address: "Alandi Markal Road, Khed, Pune" },
];

function stripFences(text) {
  if (typeof text !== "string") return "";
  const match = text.match(/\{[\s\S]*\}/);
  if (match) return match[0];
  return text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}

async function chatWithNim({ message, language = "en", imageBase64, mimetype, context = {} }) {
  const langCode = (language || "en").toLowerCase();
  const langPrompt = langCode.startsWith("mr")
    ? "Respond ENTIRELY in natural, respectful Marathi language (मराठी)."
    : langCode.startsWith("hi")
    ? "Respond ENTIRELY in natural, respectful Hindi language (हिन्दी)."
    : "Respond in clear English.";

  const systemPrompt = `You are Kabadiwala Connect AI Copilot running on NVIDIA NIM enterprise acceleration.
${langPrompt}
Available Authorized Recyclers in Maharashtra: ${JSON.stringify(TOP_RECYCLERS)}
User Context: ${JSON.stringify(context)}

Analyze the user's scrap query, calculate fair valuation, recommend the best-paying recycler with justification, and return ONLY a valid JSON object:
{
  "reply": "2-3 dynamic sentences in ${langCode.startsWith('mr') ? 'Marathi' : langCode.startsWith('hi') ? 'Hindi' : 'English'} explaining exact valuation, recommended recycler, and a bargaining tip.",
  "detected_material": "copper_wire | pcb | battery | motor | mixed_plastics | paper",
  "category_name": "Human-readable category name",
  "estimated_weight_kg": number,
  "suggested_rate_per_kg": number,
  "total_estimated_value_inr": number,
  "best_paying_recycler": {
    "name": "Recycler name from list",
    "rate_per_kg": number,
    "distance_km": number,
    "address": "Address",
    "reason": "Why this facility pays highest"
  },
  "suggested_actions": ["3 short action chips in requested language"],
  "can_create_lot": true
}`;

  const messages = [
    { role: "system", content: systemPrompt },
  ];

  if (imageBase64) {
    const mime = mimetype || "image/jpeg";
    messages.push({
      role: "user",
      content: [
        { type: "text", text: message || "Analyze this scrap photo and estimate value" },
        {
          type: "image_url",
          image_url: { url: `data:${mime};base64,${imageBase64}` },
        },
      ],
    });
  } else {
    messages.push({
      role: "user",
      content: message || "Analyze scrap and give valuation",
    });
  }

  for (const model of NIM_MODELS) {
    try {
      const response = await axios.post(
        "https://integrate.api.nvidia.com/v1/chat/completions",
        {
          model,
          messages,
          temperature: 0.2,
          max_tokens: 600,
        },
        {
          headers: {
            Authorization: `Bearer ${NVIDIA_API_KEY}`,
            "Content-Type": "application/json",
          },
          timeout: 25000,
        }
      );

      const content = response.data?.choices?.[0]?.message?.content;
      if (content) {
        const parsed = JSON.parse(stripFences(content));
        if (parsed.reply) {
          logger.info(`NVIDIA NIM model ${model} answered query successfully`);
          return parsed;
        }
      }
    } catch (e) {
      logger.warn(`NVIDIA NIM model ${model} failed: ${e.message}`);
    }
  }

  return null;
}

async function analyzeImageNim({ fileBuffer, mimetype, weightKg }) {
  const base64 = fileBuffer.toString("base64");
  const mime = mimetype || "image/jpeg";

  for (const model of ["meta/llama-3.2-11b-vision-instruct", "meta/llama-3.2-90b-vision-instruct"]) {
    try {
      const response = await axios.post(
        "https://integrate.api.nvidia.com/v1/chat/completions",
        {
          model,
          messages: [
            {
              role: "system",
              content:
                "You identify scrap & e-waste photos for Kabadiwala Connect in India. Return JSON ONLY with keys: material (pcb, battery, cable, motor, crt, lcd_panel, mixed_plastics, paper), electronic_device, short_description, confidence (0 to 1), suggested_condition (good, average, scrap), estimated_weight_kg (number), suggestions (array of 3 strings).",
            },
            {
              role: "user",
              content: [
                { type: "text", text: "Classify this scrap photograph." },
                { type: "image_url", image_url: { url: `data:${mime};base64,${base64}` } },
              ],
            },
          ],
          temperature: 0.1,
          max_tokens: 400,
        },
        {
          headers: {
            Authorization: `Bearer ${NVIDIA_API_KEY}`,
            "Content-Type": "application/json",
          },
          timeout: 25000,
        }
      );

      const content = response.data?.choices?.[0]?.message?.content;
      if (content) {
        const parsed = JSON.parse(stripFences(content));
        if (parsed.material) {
          return parsed;
        }
      }
    } catch (e) {
      logger.warn(`NVIDIA NIM vision ${model} failed: ${e.message}`);
    }
  }

  return null;
}

module.exports = {
  chatWithNim,
  analyzeImageNim,
  NVIDIA_API_KEY,
};
