"""
context_service.py — K5.1 / K5.2
Spike risk calculation based on meal GI, sleep quality, steps taken,
and current glucose reading.

Returns: "low" | "medium" | "high"
Used by: GET /api/v1/recommend/{user_id}
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# ── Thresholds (tunable) ────────────────────────────────────────────────────
_HIGH_GI_THRESHOLD    = 60      # GI > 60 → inherently high spike risk
_MEDIUM_GI_THRESHOLD  = 45
_HIGH_GLUCOSE_MG_DL   = 160     # current blood glucose already elevated
_MEDIUM_GLUCOSE_MG_DL = 130
_LOW_SLEEP_SCORE      = 0.45    # poor sleep → higher insulin resistance
_MEDIUM_SLEEP_SCORE   = 0.65
_LOW_STEPS            = 2_000   # sedentary → less ambient glucose clearance
_MEDIUM_STEPS         = 5_000


def calculate_spike_risk(
    gi: Optional[float] = None,
    sleep_score: Optional[float] = None,   # 0.0–1.0
    steps: Optional[int] = None,           # steps since midnight
    current_glucose: Optional[float] = None,  # mg/dL
) -> str:
    """
    Calculate post-meal glucose spike risk.

    Scoring: each factor contributes 0, 1, or 2 points.
    Total ≥ 5 → "high" | 3–4 → "medium" | ≤ 2 → "low"

    Args:
        gi              : Glycemic Index of the primary meal (0–100)
        sleep_score     : 0.0 (terrible) – 1.0 (perfect)
        steps           : steps logged so far today
        current_glucose : latest glucometer reading in mg/dL

    Returns:
        "low" | "medium" | "high"
    """
    score = 0

    # ── Factor 1: Meal GI ──────────────────────────────────────────────────
    if gi is not None:
        if gi > _HIGH_GI_THRESHOLD:
            score += 2
            logger.debug("spike_risk: GI=%s → +2 (high GI)", gi)
        elif gi > _MEDIUM_GI_THRESHOLD:
            score += 1
            logger.debug("spike_risk: GI=%s → +1 (medium GI)", gi)
        else:
            logger.debug("spike_risk: GI=%s → +0 (low GI)", gi)

    # ── Factor 2: Sleep quality ────────────────────────────────────────────
    if sleep_score is not None:
        if sleep_score < _LOW_SLEEP_SCORE:
            score += 2
            logger.debug("spike_risk: sleep=%.2f → +2 (poor sleep)", sleep_score)
        elif sleep_score < _MEDIUM_SLEEP_SCORE:
            score += 1
            logger.debug("spike_risk: sleep=%.2f → +1 (moderate sleep)", sleep_score)

    # ── Factor 3: Steps (sedentary penalty) ───────────────────────────────
    if steps is not None:
        if steps < _LOW_STEPS:
            score += 2
            logger.debug("spike_risk: steps=%d → +2 (sedentary)", steps)
        elif steps < _MEDIUM_STEPS:
            score += 1
            logger.debug("spike_risk: steps=%d → +1 (light activity)", steps)

    # ── Factor 4: Current glucose ──────────────────────────────────────────
    if current_glucose is not None:
        if current_glucose > _HIGH_GLUCOSE_MG_DL:
            score += 5  # Force high risk when baseline is already very high
            logger.debug(
                "spike_risk: glucose=%.0f → +5 (already elevated)", current_glucose
            )
        elif current_glucose > _MEDIUM_GLUCOSE_MG_DL:
            score += 1
            logger.debug(
                "spike_risk: glucose=%.0f → +1 (slightly elevated)", current_glucose
            )

    # ── Map score → risk level ─────────────────────────────────────────────
    if score >= 5:
        risk = "high"
    elif score >= 3:
        risk = "medium"
    else:
        risk = "low"

    logger.info(
        "calculate_spike_risk(gi=%s, sleep=%.2f, steps=%s, glucose=%s) → score=%d → %s",
        gi,
        sleep_score or 0.0,
        steps,
        current_glucose,
        score,
        risk,
    )
    return risk


def get_context_warning(
    current_glucose: Optional[float],
    sleep_score: Optional[float],
    spike_risk: str,
) -> Optional[str]:
    """
    Generate a human-readable context warning string for the dashboard.
    Returns None if no warnings needed.
    """
    warnings = []

    if current_glucose is not None and current_glucose > _HIGH_GLUCOSE_MG_DL:
        warnings.append(f"⚠️ High glucose ({current_glucose:.0f} mg/dL) — choose low-GI options")

    if sleep_score is not None and sleep_score < _LOW_SLEEP_SCORE:
        warnings.append("😴 Poor sleep detected — insulin resistance may be elevated today")

    if spike_risk == "high":
        warnings.append("🔴 High spike risk — prioritise fibre-first eating order")

    return " | ".join(warnings) if warnings else None
