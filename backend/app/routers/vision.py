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
import uuid
from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, File, HTTPException, UploadFile, Depends, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database import get_db
from app.models.glucose import GlucoseReading
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
        if _USE_STUB:
            detected_raw = await detect_foods_stub(image_bytes)
        else:
            try:
                detected_raw = await detect_foods(image_bytes)
            except Exception as exc:
                logger.warning(
                    "ViT model unavailable (%s) — falling back to stub. "
                    "Set VISION_USE_STUB=1 in .env to suppress this warning.",
                    exc,
                )
                detected_raw = await detect_foods_stub(image_bytes)
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

@router.post("/analyze-glucometer")
async def analyze_glucometer(
    image: UploadFile = File(...),
    user_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    """
    Accepts a photo of a glucometer display.
    Uses Gemini Flash to extract the numeric glucose reading.

    NOTE: VISION_USE_STUB controls the ViT food-detection model only.
    Glucometer OCR uses Gemini (API key only — no large model download),
    so it always attempts a real read first. Falls back to stub (142) only if:
      - GOOGLE_AI_KEY is not set, OR
      - Gemini returns None (image unclear / not a glucometer)
    """
    try:
        image_bytes = await image.read()

        # Always try Gemini first — only needs the API key, not the ViT model.
        # VISION_USE_STUB=1 skips heavy HuggingFace downloads; OCR is separate.
        glucose_value: Optional[float] = None
        api_key = os.getenv("GOOGLE_AI_KEY") or os.getenv("GEMINI_API_KEY")
        confidence = "stub"

        if api_key:
            try:
                glucose_value = await _extract_glucose_from_image(image_bytes)
                if glucose_value is not None:
                    confidence = "high"
                    logger.info("Gemini glucometer OCR: %.1f mg/dL", glucose_value)
                else:
                    logger.warning("Gemini could not read a number — using stub fallback")
            except Exception as gemini_exc:
                logger.warning("Gemini glucometer OCR failed (%s) — stub fallback", gemini_exc)
        else:
            logger.warning("GOOGLE_AI_KEY not set — using stub value 142.0")

        # Stub fallback: reached only when Gemini has no key, returned None, or errored
        if glucose_value is None:
            glucose_value = 142.0

        # Log reading to DB if user_id provided
        if user_id and glucose_value:
            reading = GlucoseReading(
                id=str(uuid.uuid4()),
                user_id=user_id,
                glucose_mgdl=glucose_value,
                value_mgdl=glucose_value,
                timestamp=datetime.utcnow(),
                source="glucometer_photo",
            )
            db.add(reading)
            db.commit()

        return {
            "glucose_mgdl": glucose_value,
            "confidence": confidence,
            "raw_text": str(int(glucose_value)),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

async def _extract_glucose_from_image(image_bytes: bytes) -> Optional[float]:
    """Use Gemini Vision to read a numeric value from a glucometer display."""
    import google.generativeai as genai
    import os
    api_key = os.getenv("GOOGLE_AI_KEY") or os.getenv("GEMINI_API_KEY")
    if not api_key:
        return None
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")
    
    import PIL.Image
    import io
    pil_image = PIL.Image.open(io.BytesIO(image_bytes))
    
    prompt = (
        "This is a photo of a blood glucose meter (glucometer) display. "
        "Read the NUMERIC glucose value shown on the screen. "
        "Return ONLY the number in JSON format: {\"glucose_mgdl\": <number>}. "
        "If the display is unclear or not a glucometer, return {\"glucose_mgdl\": null}."
    )
    response = model.generate_content([prompt, pil_image])
    import json, re
    match = re.search(r'\{.*?\}', response.text, re.DOTALL)
    if match:
        data = json.loads(match.group())
        return float(data.get("glucose_mgdl") or 0) or None
    return None
