"""Map model material labels onto collector lot categories (EN labels)."""

from __future__ import annotations

LOT_CATEGORIES: dict[str, dict[str, str]] = {
    "pcb_motherboard": {
        "category": "Motherboard / PCB",
        "electronic_device": "Circuit board / converter module",
        "short_description": "Populated PCB with chips or power parts; best match is Motherboard / PCB.",
    },
    "copper_wire": {
        "category": "Copper Wire",
        "electronic_device": "Electrical cable / copper wire",
        "short_description": "Insulated copper wiring or cable bundle; best match is Copper Wire.",
    },
    "battery": {
        "category": "Batteries",
        "electronic_device": "9V / dry-cell battery",
        "short_description": "Branded battery cell or pack; best match is Batteries.",
    },
    "display_monitor": {
        "category": "Monitors & Displays",
        "electronic_device": "Display panel",
        "short_description": "LCD, LED, or CRT screen; best match is Monitors & Displays.",
    },
    "heavy_appliances": {
        "category": "Heavy Electricals",
        "electronic_device": "Electric motor / appliance part",
        "short_description": "Motor, magnet, or heavy electrical assembly; best match is Heavy Electricals.",
    },
    "plastic": {
        "category": "Plastic",
        "electronic_device": "Plastic housing or parts",
        "short_description": "Plastic casing or mixed plastic scrap; best match is Plastic.",
    },
    "paper": {
        "category": "Paper",
        "electronic_device": "Paper waste",
        "short_description": "Loose paper or cardboard; best match is Paper.",
    },
    "book": {
        "category": "Books",
        "electronic_device": "Books",
        "short_description": "Bound books or notebooks; best match is Books.",
    },
    "mixed_ewaste": {
        "category": "Mixed E-Waste",
        "electronic_device": "Unidentified electronic item",
        "short_description": "Could not match a single type with confidence; best match is Mixed E-Waste.",
    },
}

_MATERIAL_TO_CATEGORY_ID: dict[str, str] = {
    "pcb": "pcb_motherboard",
    "pcb_motherboard": "pcb_motherboard",
    "motherboard": "pcb_motherboard",
    "cable": "copper_wire",
    "copper": "copper_wire",
    "copper_wire": "copper_wire",
    "battery": "battery",
    "batteries": "battery",
    "lcd_panel": "display_monitor",
    "crt": "display_monitor",
    "display": "display_monitor",
    "display_monitor": "display_monitor",
    "motor": "heavy_appliances",
    "magnet_bearing_assembly": "heavy_appliances",
    "heavy_appliances": "heavy_appliances",
    "mixed_plastics": "plastic",
    "plastic": "plastic",
    "paper": "paper",
    "book": "book",
    "books": "book",
}


def lot_fields_for_material(material: str) -> dict[str, str]:
    key = (material or "").strip().lower()
    category_id = _MATERIAL_TO_CATEGORY_ID.get(key, "mixed_ewaste")
    info = LOT_CATEGORIES[category_id]
    return {
        "category_id": category_id,
        "category": info["category"],
        "electronic_device": info["electronic_device"],
        "short_description": info["short_description"],
    }
