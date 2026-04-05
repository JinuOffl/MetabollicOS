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
