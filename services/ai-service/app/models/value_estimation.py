from pydantic import BaseModel, Field


class ValueEstimate(BaseModel):
    estimated_value_inr: float | None = Field(
        default=None,
        ge=0.0,
    )
    confidence: float = Field(
        ge=0.0,
        le=1.0,
    )
    rate_per_kg_inr: float | None = Field(
        default=None,
        ge=0.0,
    )
    method: str
