"""
routers/vision.py  — K4.3
POST /api/v1/analyze-meal

Accepts a multipart image upload, runs ViT food detection,
then generates an eating sequence via Gemini 1.5 Flash.

Response shape:
{
  "detected_items": [{"label": "Idli", "confidence": 0.92}, ...],
  "eating_sequence": [
    {"step": 1, "food": "Sambar", "category": "Fiber", "reason": "..."},
    ...
  ],
  "spike_without_order_mg_dl": 67,
  "spike_with_order_mg_dl":    28,
  "reduction_percent":         58
}
"""

import logging
import os
from typing import List

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from app.services.vision_service import detect_foods
from app.services.sequence_service import generate_eating_sequence

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Vision AI"])

# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MAX_IMAGE_BYTES = 10 * 1024 * 1024   # 10 MB hard limit
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}

# Feature flag: set VISION_USE_STUB=1 in .env to bypass HuggingFace & Gemini
_USE_STUB = os.getenv("VISION_USE_STUB", "0") == "1"


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------

@router.post(
    "/analyze-meal",
    response_model=AnalyzeMealResponse,
    summary="Detect food items and generate eating sequence",
    description=(
        "Upload a meal photo. GlucoNav detects Indian food items using a ViT model "
        "and returns a Gemini-generated eating order to minimise glucose spike."
    ),
)
async def analyze_meal(
    image: UploadFile = File(..., description="Meal photo (JPEG / PNG / WebP, max 10 MB)"),
):
    # ── Validate content type ──────────────────────────────────────────────
    if image.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported image type '{image.content_type}'. Use JPEG, PNG, or WebP.",
        )

    # ── Read bytes ──────────────────────────────────────────────────────────
    image_bytes = await image.read()
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large ({len(image_bytes) // 1024} KB). Max is 10 MB.",
        )

    logger.info(
        "analyze_meal: received '%s' (%d bytes, type=%s)",
        image.filename, len(image_bytes), image.content_type,
    )

    # ── Step 1: Food Detection ─────────────────────────────────────────────
    try:
        if _USE_STUB:
            from app.services.vision_service import detect_foods_stub
            detected_raw = await detect_foods_stub(image_bytes)
        else:
            detected_raw = await detect_foods(image_bytes)
    except Exception as exc:
        logger.error("Food detection failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Food detection error: {exc}")

    if not detected_raw:
        raise HTTPException(
            status_code=422,
            detail="No food items could be confidently detected in the image. Try a clearer photo.",
        )

    detected_items = [DetectedItem(**item) for item in detected_raw]
    food_names = [item.label for item in detected_items]

    # ── Step 2: Eating Sequence Generation ────────────────────────────────
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
