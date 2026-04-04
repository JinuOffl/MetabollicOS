from pydantic import BaseModel
from typing import Optional

class MealResponse(BaseModel):
    id: str
    name: str
    cuisine: str
    meal_type: str
    gi: float
    gl: float
    calories: float
    protein: float
    carbs: float
    fat: float
    prep_time: int
    tags: str

    class Config:
        from_attributes = True
