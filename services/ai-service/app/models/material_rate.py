from pydantic import BaseModel, Field


class MaterialRate(BaseModel):
    material: str
    rate_per_kg_inr: float = Field(ge=0.0)
    currency: str = "INR"
    source: str
    effective_date: str
