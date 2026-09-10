from app.models.value_estimation import ValueEstimate
from app.models.weight_estimation import WeightEstimate


def estimate_weight() -> WeightEstimate:
    return WeightEstimate(
        estimated_weight_kg=None,
        confidence=0.0,
        method="not_available",
    )


def estimate_value() -> ValueEstimate:
    return ValueEstimate(
        estimated_value_inr=None,
        confidence=0.0,
        rate_per_kg_inr=None,
        method="not_available",
    )
