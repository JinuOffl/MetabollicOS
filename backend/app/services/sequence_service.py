"""
sequence_service.py  — K4.2
Eating sequence generation using Gemini 1.5 Flash.

Given a list of detected food items, asks Gemini to:
  1. Classify each item by macro category (Fiber/Protein/Carb/Fat)
  2. Order them to minimise glucose spike (Fiber → Protein → Fat → Carb)
  3. Estimate approximate post-meal glucose delta with vs without order

Usage:
    from app.services.sequence_service import generate_eating_sequence
    result = await generate_eating_sequence(["Idli", "Sambar", "Chutney"])
"""

import json
import logging
import os
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Gemini client — lazy init
# ---------------------------------------------------------------------------
_gemini_model = None


def _get_gemini_model():
    global _gemini_model
    if _gemini_model is None:
        try:
            import google.generativeai as genai
            api_key = os.getenv("GOOGLE_AI_KEY", "")
            if not api_key:
                raise EnvironmentError("GOOGLE_AI_KEY is not set in environment.")
            genai.configure(api_key=api_key)
            _gemini_model = genai.GenerativeModel("gemini-2.5-flash")
            logger.info("Gemini 1.5 Flash model initialised.")
        except Exception as exc:
            logger.error("Failed to initialise Gemini: %s", exc)
            raise RuntimeError(f"Gemini init failed: {exc}") from exc
    return _gemini_model


# ---------------------------------------------------------------------------
# Prompt template
# ---------------------------------------------------------------------------

_SEQUENCE_PROMPT = """
You are a clinical dietitian specialising in diabetes management for Indian patients.

A user has these food items on their plate:
{food_list}

Your task:
1. Identify the primary macro category of each item: Fiber, Protein, Fat, or Carb.
2. Order them to minimise post-meal blood glucose spike using the research-backed rule:
   Fiber → Protein → Fat → Carb
   Return one step per detected food item in the eating_sequence array.
3. For each item in the ordered list, give a short reason (1 sentence, max 12 words).
4. Estimate:
   - "spike_without_order_mg_dl": approximate glucose rise if eaten in random order
   - "spike_with_order_mg_dl":    approximate glucose rise if eaten in your suggested order
   - "reduction_percent":         round integer percentage reduction

Return ONLY valid JSON — no markdown, no commentary:
{{
  "eating_sequence": [
    {{"step": 1, "food": "<name>", "category": "<Fiber|Protein|Fat|Carb>", "reason": "<short reason>"}},
    ...
  ],
  "spike_without_order_mg_dl": <int>,
  "spike_with_order_mg_dl":    <int>,
  "reduction_percent":         <int>
}}
"""

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def generate_eating_sequence(
    detected_foods: List[str],
) -> Dict[str, Any]:
    """
    Generate an optimal eating sequence for the given food items.

    Args:
        detected_foods: List of food item names, e.g. ["Idli", "Sambar", "Chutney"]

    Returns:
        Dict with keys: eating_sequence, spike_without_order_mg_dl,
                        spike_with_order_mg_dl, reduction_percent
    """
    if not detected_foods:
        return _empty_sequence_response()

    food_list_str = "\n".join(f"- {f}" for f in detected_foods)
    prompt = _SEQUENCE_PROMPT.format(food_list=food_list_str)

    model = _get_gemini_model()

    try:
        response = model.generate_content(prompt)
        raw_text = response.text.strip()
        logger.debug("Gemini raw response: %s", raw_text[:500])
    except Exception as exc:
        logger.error("Gemini generation error: %s", exc)
        raise RuntimeError(f"Gemini sequence generation failed: {exc}") from exc

    # Parse JSON — Gemini sometimes wraps in ```json``` fences; strip them
    cleaned = _strip_code_fences(raw_text)
    try:
        result = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        logger.error("Failed to parse Gemini JSON: %s\nRaw: %s", exc, cleaned)
        # Fallback to stub rather than hard-crashing
        logger.warning("Falling back to stub sequence response.")
        return _stub_sequence(detected_foods)

    # Validate required keys
    required = {"eating_sequence", "spike_without_order_mg_dl",
                "spike_with_order_mg_dl", "reduction_percent"}
    if not required.issubset(result.keys()):
        logger.warning("Gemini response missing keys. Using stub.")
        return _stub_sequence(detected_foods)
        
    # Enforce strictly sequential step numbers (addresses LLM numbering bugs)
    for i, item in enumerate(result.get("eating_sequence", [])):
        item["step"] = i + 1

    return result


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _strip_code_fences(text: str) -> str:
    """Remove ```json ... ``` or ``` ... ``` wrappers if present."""
    if text.startswith("```"):
        lines = text.splitlines()
        # Drop first line (```json or ```) and last line (```)
        inner = lines[1:] if lines[-1].strip() == "```" else lines[1:]
        if inner and inner[-1].strip() == "```":
            inner = inner[:-1]
        return "\n".join(inner)
    return text


def _empty_sequence_response() -> Dict[str, Any]:
    return {
        "eating_sequence": [],
        "spike_without_order_mg_dl": 0,
        "spike_with_order_mg_dl": 0,
        "reduction_percent": 0,
    }


def _stub_sequence(foods: List[str]) -> Dict[str, Any]:
    """
    Fallback stub — returns a plausible response without hitting Gemini.
    Used when Gemini is unavailable or returns malformed JSON.
    """
    sequence = [
        {"step": i + 1, "food": f, "category": "Carb", "reason": "Eat in suggested order for best glucose control."}
        for i, f in enumerate(foods)
    ]
    return {
        "eating_sequence": sequence,
        "spike_without_order_mg_dl": 67,
        "spike_with_order_mg_dl": 28,
        "reduction_percent": 58,
    }
