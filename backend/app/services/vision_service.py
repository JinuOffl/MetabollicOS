"""
vision_service.py
Gemini Vision-based Indian food detection.

Primary:  Gemini 1.5 Flash vision API — detects whatever is actually in the photo.
Fallback: Empty list (caller raises 422) if Gemini is also unavailable.

Usage:
    from app.services.vision_service import detect_foods
    items = await detect_foods(image_bytes)
    # returns: [{"label": "Rice", "confidence": 0.92}, {"label": "Dal", "confidence": 0.88}, ...]
    # These labels are fed directly into sequence_service → Gemini categorises
    # them as Fiber / Protein / Fat / Carb and generates the optimal eating order.
"""

import io
import json
import logging
import os
import re
from typing import Any, Dict, List

import google.generativeai as genai
from PIL import Image

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Gemini Vision — primary food detector
# ---------------------------------------------------------------------------

async def _detect_with_gemini(image_bytes: bytes) -> List[Dict[str, Any]]:
    """
    Use Gemini 1.5 Flash to identify food items in the photo.
    Returns a list of {label, confidence} dicts.
    Raises RuntimeError if Gemini is unavailable or returns no usable data.
    """
    api_key = os.getenv("GOOGLE_AI_KEY") or os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GOOGLE_AI_KEY not set — cannot use Gemini Vision.")

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")

    pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    prompt = (
        "Look at this food photo carefully. "
        "Identify every distinct food item visible on the plate. "
        "For each item give a confidence score between 0.0 and 1.0. "
        "Return ONLY a valid JSON array — no markdown, no explanation:\n"
        '[{"label": "<food name>", "confidence": <0.0-1.0>}, ...]'
    )

    response = model.generate_content([prompt, pil_image])
    raw = response.text.strip()
    logger.debug("Gemini raw response: %s", raw[:300])

    # Strip markdown code fences if present
    if "```" in raw:
        match = re.search(r'\[.*?\]', raw, re.DOTALL)
        raw = match.group() if match else raw

    detected = json.loads(raw)

    if not isinstance(detected, list) or len(detected) == 0:
        raise RuntimeError("Gemini returned empty or invalid food list.")

    # Normalise labels to Title Case
    result = [
        {
            "label": str(item.get("label", "Food")).strip().title(),
            "confidence": round(float(item.get("confidence", 0.8)), 4),
        }
        for item in detected
        if isinstance(item, dict) and item.get("label")
    ]

    logger.info("Gemini Vision detected: %s", [r["label"] for r in result])
    return result


# ---------------------------------------------------------------------------
# Public API — called by vision.py router
# ---------------------------------------------------------------------------

async def detect_foods(image_bytes: bytes) -> List[Dict[str, Any]]:
    """
    Primary food detection entry point.
    Uses Gemini Vision to identify whatever is actually in the photo.
    Raises RuntimeError on failure (router converts to HTTP 500).
    """
    return await _detect_with_gemini(image_bytes)


async def detect_foods_stub(image_bytes: bytes) -> List[Dict[str, Any]]:
    """
    Fallback — also uses Gemini Vision (same as detect_foods).
    Called by the router when VISION_USE_STUB=1 or as a ViT fallback.
    If Gemini is also unavailable, raises RuntimeError so the router
    returns a clean 500 instead of silent mock data.
    """
    return await _detect_with_gemini(image_bytes)
