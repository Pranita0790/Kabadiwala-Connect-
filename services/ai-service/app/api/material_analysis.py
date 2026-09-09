from fastapi import APIRouter

from app.models.material_analysis import MaterialAnalysisResponse
from app.services.material_analysis import analyze_material


router = APIRouter(
    prefix="/api/v1",
    tags=["Material Analysis"],
)


@router.post(
    "/analyze",
    response_model=MaterialAnalysisResponse,
)
def analyze() -> MaterialAnalysisResponse:
    return analyze_material()
