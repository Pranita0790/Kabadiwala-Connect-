from typing import Literal

from pydantic import BaseModel, Field

from app.models.value_estimation import ValueEstimate
from app.models.weight_estimation import WeightEstimate


MaterialName = Literal[
    "crt",
    "lcd_panel",
    "pcb",
    "cable",
    "battery",
    "motor",
    "magnet_bearing_assembly",
    "mixed_plastics",
    "unknown",
]


class MaterialAnalysisResponse(BaseModel):
    material: MaterialName
    confidence: float = Field(ge=0.0, le=1.0)
    critical_mineral: bool
    critical_mineral_reason: str | None
    model_version: str
    rule_version: str
    supported_materials: list[MaterialName]
    weight_estimate: WeightEstimate
    value_estimate: ValueEstimate
