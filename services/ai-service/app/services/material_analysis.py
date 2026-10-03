from PIL import Image

from app.models.material_analysis import MaterialAnalysisResponse
from app.services.critical_mineral import check_critical_mineral
from app.services.estimation import estimate_value, estimate_weight
from app.services.material_capabilities import SUPPORTED_MATERIALS
from app.services.material_classifier import (
    MODEL_VERSION,
    classify_material,
    suggested_condition,
    typical_weight_kg,
)


def analyze_material(
    image: Image.Image,
    weight_kg: float | None = None,
) -> MaterialAnalysisResponse:

    classification = classify_material(image)

    critical_result = check_critical_mineral(
        classification.material
    )

    resolved_weight = (
        weight_kg
        if weight_kg is not None
        else typical_weight_kg(classification.material)
    )
    weight_method = "user_provided" if weight_kg is not None else "typical_lot"

    return MaterialAnalysisResponse(
        material=classification.material,
        confidence=classification.confidence,
        critical_mineral=critical_result.critical_mineral,
        critical_mineral_reason=critical_result.critical_mineral_reason,
        model_version=MODEL_VERSION,
        rule_version=critical_result.rule_version,
        supported_materials=list(SUPPORTED_MATERIALS),
        weight_estimate=estimate_weight(resolved_weight, method=weight_method),
        value_estimate=estimate_value(
            classification.material,
            resolved_weight,
        ),
        suggested_condition=suggested_condition(classification.material),
    )
