from pydantic import BaseModel
from typing import List, Optional

class DietRecommendation(BaseModel):
    meal_id: str
    name: str
    predicted_spike_mgdl: Optional[float] = None
    rationale: str

class ExerciseRecommendation(BaseModel):
    exercise_id: str
    name: str
    duration: int
    glucose_drop_mgdl: Optional[float] = None
    rationale: Optional[str] = None

class RecommendResponse(BaseModel):
    diet_list: List[DietRecommendation]
    exercise_list: List[ExerciseRecommendation]
    context_warning: Optional[str] = None
    coach_mode: str
