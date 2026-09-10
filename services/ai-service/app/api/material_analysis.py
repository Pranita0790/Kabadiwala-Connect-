from io import BytesIO

from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError

from app.models.material_analysis import MaterialAnalysisResponse
from app.services.material_analysis import analyze_material


router = APIRouter(
    prefix="/api/v1",
    tags=["Material Analysis"],
)

MAX_IMAGE_SIZE = 10 * 1024 * 1024


@router.post(
    "/analyze",
    response_model=MaterialAnalysisResponse,
)
async def analyze(
    file: UploadFile = File(...),
) -> MaterialAnalysisResponse:

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="Only image files are supported.",
        )

    image_bytes = await file.read()

    if len(image_bytes) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=413,
            detail="Image file is too large. Maximum size is 10 MB.",
        )

    try:
        image = Image.open(BytesIO(image_bytes))
        image.verify()
        image = Image.open(BytesIO(image_bytes)).convert("RGB")
    except (UnidentifiedImageError, OSError):
        raise HTTPException(
            status_code=400,
            detail="Invalid or unreadable image.",
        )

    return analyze_material(image)
