from pydantic import BaseModel, Field


class WeightEstimate(BaseModel):
    estimated_weight_kg: float | None = Field(
        default=None,
        ge=0.0,
    )
    confidence: float = Field(
        ge=0.0,
        le=1.0,
    )
    method: str
