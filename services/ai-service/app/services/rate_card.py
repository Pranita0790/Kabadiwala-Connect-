from app.models.material_rate import MaterialRate


RATE_CARD: dict[tuple[str, str], MaterialRate] = {
    ("pcb", "mumbai"): MaterialRate(
        material="pcb",
        subcategory=None,
        city="Mumbai",
        rate_per_kg_inr=448.33,
        source="Scrapprice Mumbai benchmark",
        effective_date="2026-09-15",
    ),

    ("cable", "mumbai"): MaterialRate(
        material="cable",
        subcategory=None,
        city="Mumbai",
        rate_per_kg_inr=396.50,
        source="Scrapprice Mumbai wire benchmark",
        effective_date="2026-09-15",
    ),

    ("battery", "mumbai"): MaterialRate(
        material="battery",
        subcategory=None,
        city="Mumbai",
        rate_per_kg_inr=100.00,
        source="Adinath Metal & Paper Mart Mumbai",
        effective_date="2026-09-01",
    ),

    ("mixed_plastics", "mumbai"): MaterialRate(
        material="mixed_plastics",
        subcategory=None,
        city="Mumbai",
        rate_per_kg_inr=64.00,
        source="Scrapprice Mumbai mixed plastic benchmark",
        effective_date="2026-09-15",
    ),
}


def get_material_rate(
    material: str,
    city: str = "Mumbai",
) -> MaterialRate | None:

    normalized_material = (
        material.strip()
        .lower()
        .replace(" ", "_")
    )

    normalized_city = city.strip().lower()

    return RATE_CARD.get(
        (normalized_material, normalized_city)
    )
