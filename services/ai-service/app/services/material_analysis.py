from PIL import Image

from app.models.material_analysis import MaterialAnalysisResponse
from app.services.critical_mineral import check_critical_mineral
from app.services.material_capabilities import MODEL_SUPPORTED_MATERIALS
from app.services.material_classifier import (
    MODEL_VERSION,
    classify_material,
)


def analyze_material(
    image: Image.Image,
) -> MaterialAnalysisResponse:

    classification = classify_material(image)

    critical_result = check_critical_mineral(
        classification.material
    )

    return MaterialAnalysisResponse(
        material=classification.material,
        confidence=classification.confidence,
        critical_mineral=critical_result.critical_mineral,
        critical_mineral_reason=critical_result.critical_mineral_reason,
        model_version=MODEL_VERSION,
        rule_version=critical_result.rule_version,
        supported_materials=list(MODEL_SUPPORTED_MATERIALS),
    )
