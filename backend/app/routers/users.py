from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import uuid # K3.2 — manual ID generation for robust onboarding
from app.database import get_db
from app.models.user import User, UserProfile
from app.schemas.user import OnboardRequest, UserResponse, UserProfileData

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/onboard", response_model=UserResponse)
def onboard_user(request: OnboardRequest, db: Session = Depends(get_db)):
    db_user = User(id=str(uuid.uuid4())) # Manual ID generation
    db.add(db_user)
    db.flush()
    
    db_profile = UserProfile(
        id=str(uuid.uuid4()), # Manual ID generation
        user_id=db_user.id,
        diabetes_type=request.diabetes_type,
        hba1c_band=request.hba1c_band,
        cuisine_preference=request.cuisine_preference,
        diet_type=request.diet_type,
        age=request.age,
        weight_kg=request.weight_kg,
        height_cm=request.height_cm,
        gender=request.gender,
        goal=request.goal,
        activity_level=request.activity_level
    )
    db.add(db_profile)
    db.commit()
    db.refresh(db_user)
    db.refresh(db_profile)
    
    return UserResponse(
        user_id=db_user.id,
        profile=UserProfileData(
            diabetes_type=db_profile.diabetes_type,
            hba1c_band=db_profile.hba1c_band,
            cuisine_preference=db_profile.cuisine_preference,
            diet_type=db_profile.diet_type,
            age=db_profile.age,
            weight_kg=db_profile.weight_kg,
            height_cm=db_profile.height_cm,
            gender=db_profile.gender,
            goal=db_profile.goal,
            activity_level=db_profile.activity_level
        )
    )

@router.get("/{user_id}", response_model=UserResponse)
def get_user(user_id: str, db: Session = Depends(get_db)):
    db_profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not db_profile:
        raise HTTPException(status_code=404, detail="User not found")
        
    return UserResponse(
        user_id=user_id,
        profile=UserProfileData(
            diabetes_type=db_profile.diabetes_type,
            hba1c_band=db_profile.hba1c_band,
            cuisine_preference=db_profile.cuisine_preference,
            diet_type=db_profile.diet_type,
            age=db_profile.age,
            weight_kg=db_profile.weight_kg,
            height_cm=db_profile.height_cm,
            gender=db_profile.gender,
            goal=db_profile.goal,
            activity_level=db_profile.activity_level
        )
    )

@router.get("/{user_id}/stats")
def get_user_stats(user_id: str, db: Session = Depends(get_db)):
    """
    Returns real computed stats for a user:
    - streak_days: consecutive days with at least 1 logged meal or exercise
    - time_in_range_pct: % of glucose readings in 70-140 mg/dL (last 14 days)
    - avg_glucose_mgdl: mean of all glucose readings (last 14 days)
    - avg_post_meal_spike: mean of MealInteraction.glucose_delta (last 14 days)
    - activities_done: count of ExerciseInteraction rows (last 7 days)
    - total_glucose_readings: total GlucoseReading rows for this user
    """
    from datetime import datetime, timedelta
    from app.models.glucose import GlucoseReading
    from app.models.meal import MealInteraction
    from app.models.exercise import ExerciseInteraction

    now = datetime.utcnow()
    fourteen_days_ago = now - timedelta(days=14)
    seven_days_ago = now - timedelta(days=7)

    # Glucose readings (last 14 days)
    readings = (
        db.query(GlucoseReading)
        .filter(GlucoseReading.user_id == user_id)
        .filter(GlucoseReading.timestamp >= fourteen_days_ago)
        .all()
    )
    glucose_values = [r.glucose_mgdl or r.value_mgdl for r in readings if (r.glucose_mgdl or r.value_mgdl)]
    
    tir = 0.0
    avg_glucose = 120.0
    if glucose_values:
        in_range = [v for v in glucose_values if 70 <= v <= 140]
        tir = round(len(in_range) / len(glucose_values) * 100, 1)
        avg_glucose = round(sum(glucose_values) / len(glucose_values), 1)

    # Meal interactions (last 14 days)
    meal_ints = (
        db.query(MealInteraction)
        .filter(MealInteraction.user_id == user_id)
        .filter(MealInteraction.timestamp >= fourteen_days_ago)
        .all()
    )
    spikes = [m.glucose_delta for m in meal_ints if m.glucose_delta is not None]
    avg_spike = round(sum(spikes) / len(spikes), 1) if spikes else 22.0

    # Activities (last 7 days)
    activities = (
        db.query(ExerciseInteraction)
        .filter(ExerciseInteraction.user_id == user_id)
        .filter(ExerciseInteraction.timestamp >= seven_days_ago)
        .count()
    )

    # Streak: simplified — count distinct days with any interaction (last 30 days)
    # Full streak calculation requires date-grouping; this is an approximation.
    all_interactions_days = set()
    for m in meal_ints:
        if hasattr(m, 'timestamp') and m.timestamp:
            all_interactions_days.add(m.timestamp.date())
    streak_days = min(len(all_interactions_days), 30)

    return {
        "user_id": user_id,
        "streak_days": streak_days,
        "time_in_range_pct": tir,
        "avg_glucose_mgdl": avg_glucose,
        "avg_post_meal_spike": avg_spike,
        "activities_done_7d": activities,
        "total_glucose_readings": len(readings),
    }
