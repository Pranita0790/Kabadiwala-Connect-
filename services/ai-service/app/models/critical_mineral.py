from pydantic import BaseModel, Field


class CriticalMineralCheckRequest(BaseModel):
    material: str = Field(min_length=1, max_length=100)


class CriticalMineralCheckResponse(BaseModel):
    material: str
    critical_mineral: bool
    critical_mineral_reason: str | None
    rule_version: str
