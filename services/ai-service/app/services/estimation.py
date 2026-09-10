from app.models.value_estimation import ValueEstimate
from app.models.weight_estimation import WeightEstimate
from app.services.rate_card import get_material_rate


def estimate_weight() -> WeightEstimate:
    return WeightEstimate(
        estimated_weight_kg=None,
        confidence=0.0,
        method="not_available",
    )


def estimate_value(material: str, weight_kg: float | None = None) -> ValueEstimate:
    rate = get_material_rate(material)

    if rate is None or weight_kg is None:
        return ValueEstimate(
            estimated_value_inr=None,
            confidence=0.0,
            rate_per_kg_inr=rate.rate_per_kg_inr if rate else None,
            method="not_available",
        )

    return ValueEstimate(
        estimated_value_inr=weight_kg * rate.rate_per_kg_inr,
        confidence=0.5,
        rate_per_kg_inr=rate.rate_per_kg_inr,
        method="rate_card",
    )