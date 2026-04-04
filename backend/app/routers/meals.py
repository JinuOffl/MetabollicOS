from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.schemas.meal import MealResponse
from app.models.meal import Meal

router = APIRouter(prefix="/meals", tags=["Meals"])

@router.get("", response_model=List[MealResponse])
def get_meals(db: Session = Depends(get_db)):
    meals = db.query(Meal).all()
    return meals
