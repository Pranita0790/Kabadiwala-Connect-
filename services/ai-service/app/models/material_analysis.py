from typing import Literal

from pydantic import BaseModel, Field


MaterialName = Literal[
    "crt",
    "lcd_panel",
    "pcb",
    "cable",
    "battery",
    "motor",
    "magnet_bearing_assembly",
    "mixed_plastic",
    "unknown",
]


class MaterialAnalysisResponse(BaseModel):
    material: MaterialName
    confidence: float = Field(ge=0.0, le=1.0)
    critical_mineral: bool
    critical_mineral_reason: str | None
    model_version: str
    rule_version: str
