from app.models.critical_mineral import CriticalMineralCheckResponse


RULE_VERSION = "critical-mineral-rules-0.2.0"


POTENTIAL_CRITICAL_MINERAL_MATERIALS = {
    "battery",
    "lithium_battery",
    "pcb",
    "electronic_waste",
}


def check_critical_mineral(
    material: str,
) -> CriticalMineralCheckResponse:

    normalized_material = (
        material.strip()
        .lower()
        .replace(" ", "_")
    )

    if normalized_material in POTENTIAL_CRITICAL_MINERAL_MATERIALS:

        return CriticalMineralCheckResponse(
            material=normalized_material,
            critical_mineral=True,
            critical_mineral_reason=(
                "This material category may contain or be associated "
                "with critical-mineral-bearing components. "
                "Material-specific verification is required."
            ),
            rule_version=RULE_VERSION,
        )

    return CriticalMineralCheckResponse(
        material=normalized_material,
        critical_mineral=False,
        critical_mineral_reason=None,
        rule_version=RULE_VERSION,
    )
