from app.models.critical_mineral import CriticalMineralCheckResponse


RULE_VERSION = "critical-mineral-rules-0.1.0"


# Initial demo rules.
# These rules are intentionally conservative and configurable.
# They indicate potential critical-mineral relevance based on
# material category; they do not prove elemental composition.

POTENTIAL_CRITICAL_MINERAL_MATERIALS = {
    "electronic_waste",
    "lithium_battery",
}


def check_critical_mineral(material: str) -> CriticalMineralCheckResponse:
    normalized_material = material.strip().lower().replace(" ", "_")

    if normalized_material in POTENTIAL_CRITICAL_MINERAL_MATERIALS:
        return CriticalMineralCheckResponse(
            material=normalized_material,
            critical_mineral=True,
            critical_mineral_reason=(
                "Potential critical mineral-bearing material category detected."
            ),
            rule_version=RULE_VERSION,
        )

    return CriticalMineralCheckResponse(
        material=normalized_material,
        critical_mineral=False,
        critical_mineral_reason=None,
        rule_version=RULE_VERSION,
    )
