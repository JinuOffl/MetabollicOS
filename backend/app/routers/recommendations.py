"""
routers/recommendations.py
GET /api/v1/recommend/{user_id}

K5.2 — adds spike_risk from context_service.calculate_spike_risk()
K6.3 — adds coach_mode + burnout_score from burnout_service.get_burnout_from_db()

Field normalisation: diet_engine / exercise_engine use internal naming;
_normalize_* helpers bridge them to the Pydantic schema field names.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models.user import UserProfile
from app.models.glucose import GlucoseReading # K5.2 — Real-time reactive data
from app.schemas.recommendation import RecommendResponse
from app.services.diet_engine import get_diet_recommendations
from app.services.exercise_engine import get_exercise_recommendations
from app.services.context_service import calculate_spike_risk, get_context_warning
from app.services.burnout_service import get_burnout_from_db

router = APIRouter(prefix="/recommend", tags=["Recommendations"])


# ── Field-name normalizers ────────────────────────────────────────────────────

def _normalize_diet_item(d: dict) -> dict:
    """
    Bridge diet_engine internal keys → DietRecommendation schema keys.
    diet_engine returns: meal_id, name, cuisine, meal_type,
                         predicted_spike_mg, is_vegetarian, reason, score
    schema expects:      meal_id, name, cuisine, predicted_glucose_delta,
                         predicted_spike_mgdl (legacy), gi, gl, reason, tags
    """
    spike = d.get("predicted_spike_mg") or d.get("predicted_glucose_delta")
    return {
        "meal_id":                 d.get("meal_id", ""),
        "name":                    d.get("name", ""),
        "cuisine":                 d.get("cuisine"),
        "predicted_glucose_delta": spike,
        "predicted_spike_mgdl":    spike,      # legacy alias
        "gi":                      d.get("gi") or d.get("glycemic_index"),
        "gl":                      d.get("gl"),
        "reason":                  d.get("reason") or d.get("rationale"),
        "rationale":               d.get("reason") or d.get("rationale"),  # legacy alias
        "tags":                    d.get("tags", []),
    }


def _normalize_exercise_item(d: dict) -> dict:
    """
    Bridge exercise_engine internal keys → ExerciseRecommendation schema keys.
    exercise_engine returns: exercise_id, name, exercise_type, duration_min,
                             glucose_drop_mg, burnout_cost, timing, reason, score
    schema expects:          exercise_id, name, type, duration_minutes,
                             glucose_benefit_mg_dl, burnout_cost, met, timing,
                             reason, duration (legacy), glucose_drop_mgdl (legacy)
    """
    glucose = (
        d.get("glucose_drop_mg")
        or d.get("glucose_benefit_mg_dl")
        or d.get("glucose_drop_mgdl")
    )
    duration = (
        d.get("duration_min")
        or d.get("duration_minutes")
        or d.get("duration")
    )
    return {
        "exercise_id":         d.get("exercise_id", ""),
        "name":                d.get("name", ""),
        "type":                d.get("exercise_type") or d.get("type"),
        "duration_minutes":    duration,
        "duration":            duration,          # legacy alias
        "glucose_benefit_mg_dl": glucose,
        "glucose_drop_mgdl":   glucose,           # legacy alias
        "burnout_cost":        d.get("burnout_cost"),
        "met":                 d.get("met"),
        "timing":              d.get("timing", "post_meal"),
        "reason":              d.get("reason") or d.get("rationale"),
        "rationale":           d.get("reason") or d.get("rationale"),  # legacy alias
    }


# ── Router ────────────────────────────────────────────────────────────────────

@router.get("/{user_id}", response_model=RecommendResponse)
def get_recommendations(
    user_id: str,
    # Optional context params passed by Flutter dashboard
    gi: Optional[float] = Query(None, description="GI of selected meal (0–100)"),
    sleep_score: Optional[float] = Query(None, ge=0.0, le=1.0, description="Sleep quality 0–1"),
    steps: Optional[int] = Query(None, ge=0, description="Steps taken today"),
    current_glucose: Optional[float] = Query(None, ge=0, description="Latest glucose reading mg/dL"),
    db: Session = Depends(get_db),
):
    """
    Get personalised diet + exercise recommendations for a user.

    Context params (gi, sleep_score, steps, current_glucose) are optional.
    When provided they are used to compute spike_risk and context_warning.
    If current_glucose is NOT provided, the latest entry from the 'glucose_readings' 
    table is used automatically to enable real-time reactive recommendations.
    """
    # ── 0. Real-time CGM logic ───────────────────────────────────────────
    # If no manual glucose is provided, pull the absolute latest from the DB
    actual_glucose = current_glucose
    if actual_glucose is None:
        latest_reading = (
            db.query(GlucoseReading)
            .filter(GlucoseReading.user_id == user_id)
            .order_by(GlucoseReading.timestamp.desc())
            .first()
        )
        if latest_reading:
            actual_glucose = latest_reading.glucose_mgdl or latest_reading.value_mgdl
            # print(f"📡 Real-time Logic: Using last CGM reading: {actual_glucose} mg/dL")
    # ── 1. Fetch user profile ─────────────────────────────────────────────
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail=f"User profile not found: {user_id}")

    profile_dict = {
        "diabetes_type":     profile.diabetes_type,
        "regional_cuisine":  profile.cuisine_preference,
        "diet_preference":   profile.diet_type,
        "hba1c_band":        profile.hba1c_band,
        "activity_level":    profile.activity_level or "sedentary",
        "age_band":          "40s" if not profile.age else f"{(profile.age // 10) * 10}s",
    }

    # ── 2. Get diet + exercise recommendations ────────────────────────────
    # Requesting top_n=10 to allow frontend to implement Meal Swaps from the remainder array.
    diet_raw      = get_diet_recommendations(profile_dict, top_n=10)
    exercise_raw  = get_exercise_recommendations(profile_dict, top_n=10)

    diet_list     = [_normalize_diet_item(d) for d in diet_raw]
    exercise_list = [_normalize_exercise_item(e) for e in exercise_raw]

    # Use the top meal's GI for spike risk if no explicit gi param
    effective_gi = gi
    if effective_gi is None and diet_list:
        effective_gi = diet_list[0].get("gi")

    # ── 3. K5.2 — Calculate spike risk ────────────────────────────────────
    spike_risk = calculate_spike_risk(
        gi=effective_gi,
        sleep_score=sleep_score,
        steps=steps,
        current_glucose=actual_glucose, # Use the synced variable
    )

    context_warning = get_context_warning(
        current_glucose=actual_glucose, # Use the synced variable
        sleep_score=sleep_score,
        spike_risk=spike_risk,
    )

    # ── 4. K6.3 — Calculate burnout + coach mode ──────────────────────────
    burnout_data  = get_burnout_from_db(user_id=user_id, db=db)
    burnout_score = burnout_data["burnout_score"]
    coach_mode    = burnout_data["coach_mode"]

    # ── 5. Build response ─────────────────────────────────────────────────
    return RecommendResponse(
        user_id=user_id,
        diet_list=diet_list,
        exercise_list=exercise_list,
        diet_recommendations=diet_list,
        exercise_recommendations=exercise_list,
        context_warning=context_warning,
        spike_risk=spike_risk,
        coach_mode=coach_mode,
        burnout_score=burnout_score,
        current_glucose=actual_glucose,
    )
