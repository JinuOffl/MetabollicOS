"""
routers/recommendations.py
GET /api/v1/recommend/{user_id}

Updated:
  K5.2 — adds spike_risk from context_service.calculate_spike_risk()
  K6.3 — adds coach_mode + burnout_score from burnout_service.get_burnout_from_db()
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models.user import UserProfile
from app.schemas.recommendation import RecommendResponse
from app.services.diet_engine import get_diet_recommendations
from app.services.exercise_engine import get_exercise_recommendations
from app.services.context_service import calculate_spike_risk, get_context_warning
from app.services.burnout_service import get_burnout_from_db

router = APIRouter(prefix="/recommend", tags=["Recommendations"])


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
    When provided, they are used to compute spike_risk and context_warning.
    """
    # ── 1. Fetch user profile ─────────────────────────────────────────────
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail=f"User profile not found: {user_id}")

    profile_dict = {
        "diabetes_type": profile.diabetes_type,
        "regional_cuisine": profile.cuisine_preference,
        "diet_preference": profile.diet_type,
        "hba1c_band": profile.hba1c_band,
    }

    # ── 2. Get diet + exercise recommendations ────────────────────────────
    diet_list = get_diet_recommendations(profile_dict)
    exercise_list = get_exercise_recommendations(profile_dict)

    # Use the top meal's GI for spike risk if no explicit gi param
    effective_gi = gi
    if effective_gi is None and diet_list:
        first = diet_list[0]
        effective_gi = getattr(first, "gi", None) or (
            first.get("gi") if isinstance(first, dict) else None
        )

    # ── 3. K5.2 — Calculate spike risk ────────────────────────────────────
    spike_risk = calculate_spike_risk(
        gi=effective_gi,
        sleep_score=sleep_score,
        steps=steps,
        current_glucose=current_glucose,
    )

    context_warning = get_context_warning(
        current_glucose=current_glucose,
        sleep_score=sleep_score,
        spike_risk=spike_risk,
    )

    # ── 4. K6.3 — Calculate burnout + coach mode ──────────────────────────
    burnout_data = get_burnout_from_db(user_id=user_id, db=db)
    burnout_score = burnout_data["burnout_score"]
    coach_mode = burnout_data["coach_mode"]

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
    )
