"""
burnout_service.py — K6.1 / K6.2
Diabetic management burnout detection and coach mode selection.

Burnout is calculated from recent interaction history:
  - Consecutive skipped exercise interactions → fatigue signal
  - High HIIT frequency → overtraining signal
  - Missing meals in diary → disengagement signal

coach_mode: "active" | "balanced" | "supportive"
  - active     : user is engaged, show performance metrics + challenges
  - balanced   : moderate tone, motivational but not pressuring
  - supportive : user showing burnout signs, soft language, encouragement only

Used by: GET /api/v1/recommend/{user_id}
"""

import logging
from typing import List, Optional

logger = logging.getLogger(__name__)

# ── Thresholds ───────────────────────────────────────────────────────────────
_HIGH_BURNOUT    = 7.0   # score ≥ 7 → supportive mode
_MEDIUM_BURNOUT  = 4.0   # score ≥ 4 → balanced mode
_MAX_SCORE       = 10.0


def calculate_burnout_score(
    skipped_exercise_last_7_days: int = 0,
    hiit_sessions_last_7_days: int = 0,
    missed_meals_last_7_days: int = 0,
    streak_days: int = 0,
) -> float:
    """
    Calculate a burnout score (0–10) from recent behaviour.

    Higher score = more burnout / fatigue signals.

    Args:
        skipped_exercise_last_7_days : exercises logged as 'skipped' in last 7 days
        hiit_sessions_last_7_days    : HIIT workouts completed in last 7 days
        missed_meals_last_7_days     : meal diary entries missing in last 7 days
        streak_days                  : current logging streak (longer = less burnout)

    Returns:
        float in [0.0, 10.0]
    """
    score = 0.0

    # Skipped exercises: each skip → +1.2 points (max 5 skips fills half the scale)
    skip_contribution = min(skipped_exercise_last_7_days * 1.2, 6.0)
    score += skip_contribution
    logger.debug("burnout: skips=%d → +%.1f", skipped_exercise_last_7_days, skip_contribution)

    # Excessive HIIT: > 3 sessions/week → overtraining → +1.5 per excess session
    excess_hiit = max(0, hiit_sessions_last_7_days - 3)
    hiit_contribution = min(excess_hiit * 1.5, 3.0)
    score += hiit_contribution
    logger.debug(
        "burnout: HIIT=%d (excess=%d) → +%.1f",
        hiit_sessions_last_7_days, excess_hiit, hiit_contribution,
    )

    # Missed meals: each → +0.8 (disengagement signal)
    missed_contribution = min(missed_meals_last_7_days * 0.8, 4.0)
    score += missed_contribution
    logger.debug("burnout: missed_meals=%d → +%.1f", missed_meals_last_7_days, missed_contribution)

    # Streak bonus: long streaks reduce burnout score
    streak_reduction = min(streak_days * 0.15, 3.0)
    score = max(0.0, score - streak_reduction)
    logger.debug("burnout: streak=%d → -%.1f", streak_days, streak_reduction)

    final_score = round(min(score, _MAX_SCORE), 1)
    logger.info(
        "calculate_burnout_score(skips=%d, hiit=%d, missed=%d, streak=%d) → %.1f",
        skipped_exercise_last_7_days,
        hiit_sessions_last_7_days,
        missed_meals_last_7_days,
        streak_days,
        final_score,
    )
    return final_score


def get_coach_mode(burnout_score: float) -> str:
    """
    Map burnout score → coach mode string.

    Returns:
        "supportive" if burnout_score >= 7.0
        "balanced"   if burnout_score >= 4.0
        "active"     otherwise
    """
    if burnout_score >= _HIGH_BURNOUT:
        mode = "supportive"
    elif burnout_score >= _MEDIUM_BURNOUT:
        mode = "balanced"
    else:
        mode = "active"

    logger.info("get_coach_mode(burnout=%.1f) → %s", burnout_score, mode)
    return mode


def get_burnout_from_db(user_id: str, db) -> dict:
    """
    Query the database for a user's recent interaction history
    and return calculated burnout_score + coach_mode.

    Args:
        user_id : the user's ID string
        db      : SQLAlchemy Session

    Returns:
        {"burnout_score": float, "coach_mode": str}
    """
    from app.models.meal import MealInteraction
    from app.models.exercise import ExerciseInteraction

    from datetime import datetime, timedelta
    seven_days_ago = datetime.utcnow() - timedelta(days=7)

    # Count skipped exercises
    try:
        skipped = (
            db.query(ExerciseInteraction)
            .filter(
                ExerciseInteraction.user_id == user_id,
                ExerciseInteraction.interaction_type == "skipped",
                ExerciseInteraction.timestamp >= seven_days_ago,
            )
            .count()
        )
    except Exception:
        skipped = 0

    # Count HIIT sessions
    try:
        hiit = (
            db.query(ExerciseInteraction)
            .filter(
                ExerciseInteraction.user_id == user_id,
                ExerciseInteraction.interaction_type == "completed",
                ExerciseInteraction.timestamp >= seven_days_ago,
            )
            .count()
        )
    except Exception:
        hiit = 0

    # Count missed meals (days with no meal log in last 7 days)
    try:
        logged_days = (
            db.query(MealInteraction.timestamp)
            .filter(
                MealInteraction.user_id == user_id,
                MealInteraction.timestamp >= seven_days_ago,
            )
            .all()
        )
        unique_days = len({r[0].date() for r in logged_days})
        missed = max(0, 7 - unique_days)
    except Exception:
        missed = 0

    burnout_score = calculate_burnout_score(
        skipped_exercise_last_7_days=skipped,
        hiit_sessions_last_7_days=hiit,
        missed_meals_last_7_days=missed,
    )
    coach_mode = get_coach_mode(burnout_score)

    return {"burnout_score": burnout_score, "coach_mode": coach_mode}
