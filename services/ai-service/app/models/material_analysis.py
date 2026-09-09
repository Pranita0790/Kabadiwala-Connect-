from pydantic import BaseModel, Field


class MaterialAnalysisResponse(BaseModel):
    material: str
    confidence: float = Field(ge=0.0, le=1.0)
    critical_mineral: bool
    critical_mineral_reason: str | None
    model_version: str
    rule_version: str
