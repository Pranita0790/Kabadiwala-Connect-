from dataclasses import dataclass


@dataclass(frozen=True)
class MaterialClassification:
    material: str
    confidence: float


MODEL_VERSION = "material-classifier-0.1.0"


def classify_material() -> MaterialClassification:
    """
    Temporary classifier implementation.

    The production implementation will use the trained material
    classification model. Until then, the service must not invent
    a material prediction.
    """
    return MaterialClassification(
        material="unknown",
        confidence=0.0,
    )
