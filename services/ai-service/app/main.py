from fastapi import FastAPI

from app.api.critical_mineral import router as critical_mineral_router
from app.api.material_analysis import router as material_analysis_router


app = FastAPI(
    title="Kabadiwala Connect AI Service",
    version="0.1.0",
    description="AI and material intelligence service for Kabadiwala Connect.",
)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {
        "status": "healthy",
        "service": "ai-service",
        "version": "0.1.0",
    }


app.include_router(critical_mineral_router)
app.include_router(material_analysis_router)
