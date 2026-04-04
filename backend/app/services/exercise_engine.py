"""
exercise_engine.py
------------------
High-level exercise recommendation service.

Public API
----------
get_exercise_recommendations(user_profile, context, top_n=3) -> list[dict]

Each result dict:
{
    exercise_id    : str,
    name           : str,
    exercise_type  : str,
    duration_min   : int,
    glucose_drop_mg: float,   # estimated glucose drop in mg/dL
    burnout_cost   : int,     # 1–10 scale
    timing         : str,
    reason         : str,
    score          : float,
}

Context keys (all optional):
    burnout_score : float 0–10   (> 7 = burnout filter on; exclude HIIT/strength)
    current_glucose : float mg/dL  (> 180 = prefer high glucose_benefit exercises)
    post_meal     : bool           (True = prefer post_meal timing)
    activity_level: str            (override from user_profile)
"""

from typing import List, Optional

from app.services.recommendation_service import predict_exercises

# ── Burnout threshold ─────────────────────────────────────────────────────────
BURNOUT_HIGH_THRESHOLD    = 7
EXCLUDED_TYPES_ON_BURNOUT = ["hiit", "strength"]

# ── Glucose drop estimates per benefit tier ────────────────────────────────────
_BENEFIT_TO_DROP = {
    "high":   30.0,
    "medium": 18.0,
    "low":    8.0,
}


def _estimate_glucose_drop(exercise: dict) -> float:
    benefit = str(exercise.get("glucose_benefit", "medium")).lower()
    return _BENEFIT_TO_DROP.get(benefit, 18.0)


def _build_reason(exercise: dict, burnout_score: float, post_meal: bool,
                  current_glucose: float) -> str:
    parts = []
    benefit = str(exercise.get("glucose_benefit", "medium")).lower()
    if benefit == "high":
        parts.append("High glucose-lowering benefit")
    elif benefit == "medium":
        parts.append("Moderate glucose benefit")
    else:
        parts.append("Gentle on the body")

    if burnout_score > BURNOUT_HIGH_THRESHOLD:
        parts.append("low burnout cost chosen due to fatigue")

    if post_meal and str(exercise.get("timing", "")).lower() == "post_meal":
        parts.append("ideal post-meal exercise")

    if current_glucose > 180:
        parts.append("helps blunt elevated glucose spike")

    bc = int(exercise.get("burnout_cost", 5))
    if bc <= 2:
        parts.append("minimal effort required")

    return "; ".join(parts) if parts else "Recommended for your profile"


# ── Public function ────────────────────────────────────────────────────────────

def get_exercise_recommendations(
    user_profile: dict,
    context: Optional[dict] = None,
    top_n: int = 3,
) -> List[dict]:
    """
    Parameters
    ----------
    user_profile : dict — same schema as get_diet_recommendations
    context      : dict — burnout_score, current_glucose, post_meal, activity_level

    Returns
    -------
    List of exercise recommendation dicts, sorted by score descending.
    """
    if context is None:
        context = {}

    burnout_score   = float(context.get("burnout_score", 0.0))
    current_glucose = float(context.get("current_glucose", 120.0))
    post_meal       = bool(context.get("post_meal", True))
    activity_level  = context.get("activity_level") or user_profile.get("activity_level", "sedentary")

    # ── Burnout filter ─────────────────────────────────────────────────────────
    excluded_types: List[str] = []
    if burnout_score > BURNOUT_HIGH_THRESHOLD:
        excluded_types = EXCLUDED_TYPES_ON_BURNOUT

    # ── User feature list ──────────────────────────────────────────────────────
    from app.services.diet_engine import _profile_to_feature_names
    user_feature_names = _profile_to_feature_names(user_profile)

    # ── Preferred timing ───────────────────────────────────────────────────────
    preferred_timing = "post_meal" if post_meal else None

    # ── Get candidates ─────────────────────────────────────────────────────────
    candidates = predict_exercises(
        user_feature_names=user_feature_names,
        top_n=max(top_n * 3, 9),
        excluded_exercise_types=excluded_types or None,
        preferred_timing=preferred_timing,
    )

    if not candidates:
        return []

    # ── Context re-ranking ────────────────────────────────────────────────────
    results = []
    for ex in candidates:
        adj = 0.0

        # High glucose: boost exercises with high glucose benefit
        if current_glucose > 180:
            benefit = str(ex.get("glucose_benefit", "medium")).lower()
            if benefit == "high":
                adj += 0.20
            elif benefit == "low":
                adj -= 0.10

        # Sedentary users: prefer shorter exercises (micro / short)
        dur = int(ex.get("duration_minutes", 15))
        if activity_level in ("sedentary", "light") and dur <= 10:
            adj += 0.10

        # High burnout: further boost very-low burnout-cost exercises
        if burnout_score > BURNOUT_HIGH_THRESHOLD:
            bc = int(ex.get("burnout_cost", 5))
            if bc <= 2:
                adj += 0.20
            elif bc >= 7:
                adj -= 0.30

        glucose_drop = _estimate_glucose_drop(ex)
        reason = _build_reason(ex, burnout_score, post_meal, current_glucose)

        results.append({
            "exercise_id":     ex["exercise_id"],
            "name":            ex["name"],
            "exercise_type":   ex["exercise_type"],
            "duration_min":    int(ex["duration_minutes"]),
            "glucose_drop_mg": glucose_drop,
            "burnout_cost":    int(ex["burnout_cost"]),
            "timing":          ex["timing"],
            "reason":          reason,
            "score":           ex["score"] + adj,
        })

    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:top_n]
