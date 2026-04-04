"""
diet_engine.py
--------------
High-level diet recommendation service.

Public API
----------
get_diet_recommendations(user_profile, context, top_n=5) -> list[dict]

Each result dict:
{
    meal_id           : str,
    name              : str,
    cuisine           : str,
    meal_type         : str,
    predicted_spike_mg: float,   # estimated glucose rise in mg/dL
    is_vegetarian     : bool,
    reason            : str,     # human-readable explanation
    score             : float,   # internal ranking score
}

Context keys (all optional, safe to omit):
    sleep_score     : float 0–1   (1 = excellent)
    current_glucose : float mg/dL
    meal_type       : str         ("breakfast" | "lunch" | "dinner" | "snack")
    diet_preference : str         ("vegetarian" | "vegan" | "non_vegetarian")
"""

from typing import List, Optional

from app.ml.feature_builder import user_feature_list as _build_user_features_from_row
from app.services.recommendation_service import predict_meals

import pandas as pd


# ── Glucose spike estimation ───────────────────────────────────────────────────
# Simple heuristic: GI-based spike estimate ± context modifiers.
# A proper model would learn this from historical glucose deltas; for now
# we use the glycemic index as a proxy calibrated to typical data in data_generator.py.

_GI_TO_SPIKE = {
    "low":    20.0,    # GI < 55
    "medium": 50.0,    # 55 ≤ GI ≤ 70
    "high":   75.0,    # GI > 70
}

def _estimate_spike(meal: dict, sleep_score: float, current_glucose: float) -> float:
    gi = float(meal.get("glycemic_index", 55))
    if gi < 55:
        base = _GI_TO_SPIKE["low"]
    elif gi <= 70:
        base = _GI_TO_SPIKE["medium"]
    else:
        base = _GI_TO_SPIKE["high"]

    # Sleep penalty: poor sleep → +15 mg/dL across the board
    if sleep_score < 0.5:
        base += 15.0

    # High baseline glucose → spikes land even higher
    if current_glucose > 180:
        base += 10.0

    # Fiber dampening: high fiber ≥ 6 g cuts spike by ~20%
    fiber = float(meal.get("fiber_g", 0))
    if fiber >= 6:
        base *= 0.80
    elif fiber >= 3:
        base *= 0.90

    return round(base, 1)


def _build_reason(meal: dict, sleep_score: float, current_glucose: float,
                  score_adj: float) -> str:
    parts = []
    gi = float(meal.get("glycemic_index", 55))
    if gi < 55:
        parts.append("Low-GI food")
    elif gi <= 70:
        parts.append("Medium-GI food")
    else:
        parts.append("High-GI food")

    fiber = float(meal.get("fiber_g", 0))
    if fiber >= 6:
        parts.append("high fiber dampens spike")
    elif fiber >= 3:
        parts.append("moderate fiber")

    if sleep_score < 0.5 and score_adj > 0:
        parts.append("prioritised due to poor sleep")

    if current_glucose > 180 and gi < 55:
        parts.append("safe choice given elevated glucose")

    return "; ".join(parts) if parts else "Recommended by your profile"


# ── Public function ────────────────────────────────────────────────────────────

def get_diet_recommendations(
    user_profile: dict,
    context: Optional[dict] = None,
    top_n: int = 5,
) -> List[dict]:
    """
    Parameters
    ----------
    user_profile : dict with keys matching synthetic_users.csv columns:
        diabetes_type, diet_preference, regional_cuisine, age_band,
        baseline_hba1c, thinfat_flag, activity_level

    context : dict with optional keys:
        sleep_score (0–1), current_glucose (mg/dL), meal_type, diet_preference

    Returns
    -------
    List of meal recommendation dicts, sorted by score descending.
    """
    if context is None:
        context = {}

    sleep_score     = float(context.get("sleep_score", 0.8))
    current_glucose = float(context.get("current_glucose", 120.0))
    meal_type       = context.get("meal_type")       # optional filter
    diet_pref       = context.get("diet_preference") or user_profile.get("diet_preference", "")

    # ── Build user feature list ────────────────────────────────────────────────
    user_feature_names = _profile_to_feature_names(user_profile)

    # ── Context-based score adjustments ───────────────────────────────────────
    # We'll pass these adjustments into predict_meals so ranking reflects context.
    # We generate adjustments meal-by-meal inside predict_meals via a pre-pass.
    # For simplicity here we encode sleep + glucose signals as a modifier dict.
    # We compute adjustments after getting raw predictions.

    # First pass: get more candidates than needed (2× top_n) to re-rank
    candidates = predict_meals(
        user_feature_names=user_feature_names,
        top_n=max(top_n * 3, 15),
        meal_type_filter=meal_type,
    )

    if not candidates:
        return []

    # ── Context re-ranking ────────────────────────────────────────────────────
    results = []
    for meal in candidates:
        adj = 0.0

        # Sleep penalty: boost low-GI meals when sleep is poor
        if sleep_score < 0.5 and meal["glycemic_index"] < 55:
            adj += 0.25

        # High glucose: strongly boost fiber-high, low-GI meals
        if current_glucose > 180:
            if meal["glycemic_index"] < 55:
                adj += 0.20
            if meal["fiber_g"] >= 6:
                adj += 0.10
            if meal["glycemic_index"] > 70:
                adj -= 0.30   # penalise high-GI when glucose is already high

        # Diet preference filter (soft — reduce score rather than hard exclude)
        if diet_pref in ("vegetarian", "vegan") and not meal["is_vegetarian"]:
            adj -= 0.50

        predicted_spike = _estimate_spike(meal, sleep_score, current_glucose)
        reason = _build_reason(meal, sleep_score, current_glucose, adj)

        results.append({
            "meal_id":            meal["meal_id"],
            "name":               meal["name"],
            "cuisine":            meal["cuisine"],
            "meal_type":          meal["meal_type"],
            "predicted_spike_mg": predicted_spike,
            "is_vegetarian":      meal["is_vegetarian"],
            "reason":             reason,
            "score":              meal["score"] + adj,
        })

    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:top_n]


# ── Helper ────────────────────────────────────────────────────────────────────

def _profile_to_feature_names(profile: dict) -> List[str]:
    """Convert a user_profile dict to the LightFM feature name list."""
    features = []

    dt = str(profile.get("diabetes_type", "type2")).lower().replace(" ", "_")
    features.append(f"diabetes_type:{dt}")

    diet = str(profile.get("diet_preference", "vegetarian")).lower().replace(" ", "_")
    features.append(f"diet:{diet}")

    cuisine = str(profile.get("regional_cuisine", "south_indian")).lower().replace(" ", "_")
    features.append(f"cuisine:{cuisine}")

    age_band = str(profile.get("age_band", "40s")).lower().replace(" ", "")
    features.append(f"age:{age_band}")

    hba1c = float(profile.get("baseline_hba1c", 8.0))
    if hba1c < 7.5:
        features.append("hba1c:controlled")
    elif hba1c <= 9.0:
        features.append("hba1c:moderate")
    else:
        features.append("hba1c:uncontrolled")

    thinfat = str(profile.get("thinfat_flag", "False")).strip().upper()
    features.append("thinfat:yes" if thinfat == "TRUE" else "thinfat:no")

    activity = str(profile.get("activity_level", "sedentary")).lower()
    features.append(f"activity:{activity}")

    return features
