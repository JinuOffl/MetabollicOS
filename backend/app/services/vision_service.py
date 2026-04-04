"""
vision_service.py  — K4.1
ViT-based Indian food detection.
Model: DrishtiSharma/finetuned-ViT-IndianFood-Classification-v3 (HuggingFace)

Usage:
    from app.services.vision_service import detect_foods
    items = await detect_foods(image_bytes)
    # returns: [{"label": "Idli", "confidence": 0.92}, ...]
"""

import io
import logging
from typing import List, Dict, Any

from PIL import Image

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Lazy model loading — loaded once on first call, not at import time
# ---------------------------------------------------------------------------
_pipeline = None
_MODEL_ID = "DrishtiSharma/finetuned-ViT-IndianFood-Classification-v3"


def _load_pipeline():
    """Load the HuggingFace image-classification pipeline (cached after first call)."""
    global _pipeline
    if _pipeline is None:
        try:
            from transformers import pipeline as hf_pipeline
            logger.info("Loading ViT food-classification model '%s' …", _MODEL_ID)
            _pipeline = hf_pipeline(
                "image-classification",
                model=_MODEL_ID,
                top_k=5,          # return top-5 predictions
            )
            logger.info("ViT model loaded successfully.")
        except Exception as exc:
            logger.error("Failed to load ViT model: %s", exc)
            raise RuntimeError(
                f"Could not load food-classification model '{_MODEL_ID}'. "
                "Ensure 'transformers' and 'torch' (or 'tensorflow') are installed."
            ) from exc
    return _pipeline


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def detect_foods(image_bytes: bytes) -> List[Dict[str, Any]]:
    """
    Detect Indian food items in an image.

    Args:
        image_bytes: Raw bytes of the uploaded image (JPEG / PNG / WebP).

    Returns:
        List of dicts, e.g.:
        [
            {"label": "Idli",     "confidence": 0.92},
            {"label": "Sambar",   "confidence": 0.74},
        ]
        Entries with confidence < 0.10 are filtered out.
    """
    # Decode bytes → PIL Image
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception as exc:
        raise ValueError(f"Could not decode image: {exc}") from exc

    pipe = _load_pipeline()

    # Run inference (synchronous — HF pipeline is CPU-bound)
    try:
        raw_results = pipe(image)
    except Exception as exc:
        logger.error("ViT inference error: %s", exc)
        raise RuntimeError(f"Food detection inference failed: {exc}") from exc

    # Normalise output format and filter low-confidence results
    MIN_CONFIDENCE = 0.10
    detected = [
        {
            "label": _normalise_label(r["label"]),
            "confidence": round(float(r["score"]), 4),
        }
        for r in raw_results
        if float(r["score"]) >= MIN_CONFIDENCE
    ]

    logger.info("detect_foods → %d item(s) above threshold", len(detected))
    return detected


def _normalise_label(raw_label: str) -> str:
    """
    Clean up raw model labels.
    e.g. 'LABEL_3' or underscored names → Title Case readable names.
    """
    # Replace underscores / hyphens with spaces and title-case
    cleaned = raw_label.replace("_", " ").replace("-", " ").strip().title()
    return cleaned


# ---------------------------------------------------------------------------
# Fallback stub — used during development when model isn't available locally
# ---------------------------------------------------------------------------

async def detect_foods_stub(image_bytes: bytes) -> List[Dict[str, Any]]:
    """
    Hardcoded stub for local development / unit tests.
    Returns realistic mock detections without hitting HuggingFace.
    """
    _ = image_bytes  # unused intentionally
    return [
        {"label": "Idli",   "confidence": 0.91},
        {"label": "Sambar", "confidence": 0.76},
        {"label": "Chutney","confidence": 0.55},
    ]
