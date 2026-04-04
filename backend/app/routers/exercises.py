from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.schemas.exercise import ExerciseResponse
from app.models.exercise import Exercise

router = APIRouter(prefix="/exercises", tags=["Exercises"])

@router.get("", response_model=List[ExerciseResponse])
def get_exercises(db: Session = Depends(get_db)):
    exercises = db.query(Exercise).all()
    return exercises
