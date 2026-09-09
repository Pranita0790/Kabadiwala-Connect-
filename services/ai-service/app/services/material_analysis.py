from app.models.material_analysis import MaterialAnalysisResponse
from app.services.critical_mineral import check_critical_mineral
from app.services.material_classifier import (
    MODEL_VERSION,
    classify_material,
)


def analyze_material() -> MaterialAnalysisResponse:
    classification = classify_material()

    critical_result = check_critical_mineral(classification.material)

    return MaterialAnalysisResponse(
        material=classification.material,
        confidence=classification.confidence,
        critical_mineral=critical_result.critical_mineral,
        critical_mineral_reason=critical_result.critical_mineral_reason,
        model_version=MODEL_VERSION,
        rule_version=critical_result.rule_version,
    )
