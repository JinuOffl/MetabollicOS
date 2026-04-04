from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import UserProfile
from app.schemas.recommendation import RecommendResponse
from app.services.diet_engine import get_diet_recommendations
from app.services.exercise_engine import get_exercise_recommendations

router = APIRouter(prefix="/recommend", tags=["Recommendations"])

@router.get("/{user_id}", response_model=RecommendResponse)
def get_recommendations(user_id: str, db: Session = Depends(get_db)):
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found")
        
    profile_dict = {
        "diabetes_type": profile.diabetes_type,
        "regional_cuisine": profile.cuisine_preference,
        "diet_preference": profile.diet_type,
        "hba1c_band": profile.hba1c_band
    }
    
    diet_list = get_diet_recommendations(profile_dict)
    exercise_list = get_exercise_recommendations(profile_dict)
    
    return RecommendResponse(
        diet_list=diet_list,
        exercise_list=exercise_list,
        coach_mode="balanced"
    )
