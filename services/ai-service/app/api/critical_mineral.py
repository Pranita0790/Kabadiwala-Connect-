from fastapi import APIRouter

from app.models.critical_mineral import (
    CriticalMineralCheckRequest,
    CriticalMineralCheckResponse,
)
from app.services.critical_mineral import check_critical_mineral


router = APIRouter(
    prefix="/api/v1/critical-mineral",
    tags=["Critical Mineral"],
)


@router.post(
    "/check",
    response_model=CriticalMineralCheckResponse,
)
def critical_mineral_check(
    request: CriticalMineralCheckRequest,
) -> CriticalMineralCheckResponse:
    return check_critical_mineral(request.material)
