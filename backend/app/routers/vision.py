"""
routers/vision.py  — K4.3
POST /api/v1/analyze-meal

Accepts a multipart image upload, runs ViT food detection,
then generates an eating sequence via Gemini 1.5 Flash.

I1.4 — updated content-type check to accept application/octet-stream
        so Flutter Web's MultipartFile.fromBytes() works without MediaType set.
"""

import logging
import os
from typing import List

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from app.services.vision_service import detect_foods, detect_foods_stub
from app.services.sequence_service import generate_eating_sequence

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Vision AI"])

# ── Response models ───────────────────────────────────────────────────────────

class DetectedItem(BaseModel):
    label: str
    confidence: float


class EatingStep(BaseModel):
    step: int
    food: str
    category: str   # Fiber | Protein | Fat | Carb
    reason: str


class AnalyzeMealResponse(BaseModel):
    detected_items: List[DetectedItem]
    eating_sequence: List[EatingStep]
    spike_without_order_mg_dl: int
    spike_with_order_mg_dl: int
    reduction_percent: int


# ── Constants ─────────────────────────────────────────────────────────────────

MAX_IMAGE_BYTES = 10 * 1024 * 1024   # 10 MB
# Flutter web sends application/octet-stream if content type not explicitly set
ALLOWED_CONTENT_TYPES = {
    "image/jpeg", "image/png", "image/webp", "image/gif",
    "application/octet-stream",   # Flutter web fallback
}

_USE_STUB = os.getenv("VISION_USE_STUB", "0") == "1"


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post(
    "/analyze-meal",
    response_model=AnalyzeMealResponse,
    summary="Detect food items and generate eating sequence",
)
async def analyze_meal(
    image: UploadFile = File(..., description="Meal photo (JPEG / PNG / WebP, max 10 MB)"),
):
    # Content-type guard (permissive for Flutter web)
    ct = image.content_type or "application/octet-stream"
    if ct not in ALLOWED_CONTENT_TYPES and not ct.startswith("image/"):
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported content type '{ct}'. Send an image file.",
        )

    image_bytes = await image.read()
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large ({len(image_bytes) // 1024} KB). Max 10 MB.",
        )

    logger.info("analyze_meal: %s, %d bytes, type=%s", image.filename, len(image_bytes), ct)

    # ── Step 1: Food Detection ────────────────────────────────────────────
    try:
        detected_raw = await detect_foods_stub(image_bytes) if _USE_STUB else await detect_foods(image_bytes)
    except Exception as exc:
        logger.error("Food detection failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Food detection error: {exc}")

    if not detected_raw:
        raise HTTPException(
            status_code=422,
            detail="No food items detected. Try a clearer photo or set VISION_USE_STUB=1.",
        )

    detected_items = [DetectedItem(**item) for item in detected_raw]
    food_names = [item.label for item in detected_items]

    # ── Step 2: Eating Sequence ───────────────────────────────────────────
    try:
        seq_result = await generate_eating_sequence(food_names)
    except Exception as exc:
        logger.error("Sequence generation failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Eating sequence error: {exc}")

    eating_sequence = [EatingStep(**step) for step in seq_result.get("eating_sequence", [])]

    return AnalyzeMealResponse(
        detected_items=detected_items,
        eating_sequence=eating_sequence,
        spike_without_order_mg_dl=int(seq_result.get("spike_without_order_mg_dl", 67)),
        spike_with_order_mg_dl=int(seq_result.get("spike_with_order_mg_dl", 28)),
        reduction_percent=int(seq_result.get("reduction_percent", 58)),
    )
