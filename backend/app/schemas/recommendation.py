"""
schemas/recommendation.py
Pydantic models for the /recommend endpoint.
Updated K5.2: added spike_risk field
Updated K6.3: added burnout_score field + enriched diet/exercise fields to match contracts/recommend_response.json
"""

from pydantic import BaseModel
from typing import List, Optional


class DietRecommendation(BaseModel):
    meal_id: str
    name: str
    cuisine: Optional[str] = None
    predicted_glucose_delta: Optional[float] = None   # renamed from predicted_spike_mgdl
    gi: Optional[float] = None
    gl: Optional[float] = None
    reason: Optional[str] = None                       # renamed from rationale
    tags: Optional[List[str]] = []
    insulin_dose: Optional[str] = None    # ← NEW: e.g. "4.5 units" for Type 1
    carbs_g: Optional[float] = None       # ← NEW: grams of carbs per serving
    image_url: Optional[str] = None       # ← NEW

    # Legacy aliases kept for backward compat
    predicted_spike_mgdl: Optional[float] = None
    rationale: Optional[str] = None


class ExerciseRecommendation(BaseModel):
    exercise_id: str
    name: str
    type: Optional[str] = None
    duration_minutes: Optional[int] = None             # renamed from duration
    met: Optional[float] = None
    glucose_benefit_mg_dl: Optional[float] = None      # renamed from glucose_drop_mgdl
    burnout_cost: Optional[int] = None
    reason: Optional[str] = None                       # renamed from rationale
    timing: Optional[str] = "post_meal"

    # Legacy aliases kept for backward compat
    duration: Optional[int] = None
    glucose_drop_mgdl: Optional[float] = None
    rationale: Optional[str] = None


class RecommendResponse(BaseModel):
    user_id: Optional[str] = None

    # Primary field names (matching contracts/recommend_response.json)
    diet_recommendations: Optional[List[DietRecommendation]] = []
    exercise_recommendations: Optional[List[ExerciseRecommendation]] = []

    # Legacy field names (kept so existing code doesn't break)
    diet_list: List[DietRecommendation] = []
    exercise_list: List[ExerciseRecommendation] = []
"""
schemas/recommendation.py
Pydantic models for the /recommend endpoint.
Updated K5.2: added spike_risk field
Updated K6.3: added burnout_score field + enriched diet/exercise fields to match contracts/recommend_response.json
"""

from pydantic import BaseModel
from typing import List, Optional


class DietRecommendation(BaseModel):
    meal_id: str
    name: str
    cuisine: Optional[str] = None
    predicted_glucose_delta: Optional[float] = None   # renamed from predicted_spike_mgdl
    gi: Optional[float] = None
    gl: Optional[float] = None
    reason: Optional[str] = None                       # renamed from rationale
    tags: Optional[List[str]] = []
    insulin_dose: Optional[str] = None    # ← NEW: e.g. "4.5 units" for Type 1
    carbs_g: Optional[float] = None       # ← NEW: grams of carbs per serving
    image_url: Optional[str] = None       # ← NEW

    # Legacy aliases kept for backward compat
    predicted_spike_mgdl: Optional[float] = None
    rationale: Optional[str] = None


class ExerciseRecommendation(BaseModel):
    exercise_id: str
    name: str
    type: Optional[str] = None
    duration_minutes: Optional[int] = None             # renamed from duration
    met: Optional[float] = None
    glucose_benefit_mg_dl: Optional[float] = None      # renamed from glucose_drop_mgdl
    burnout_cost: Optional[int] = None
    reason: Optional[str] = None                       # renamed from rationale
    timing: Optional[str] = "post_meal"

    # Legacy aliases kept for backward compat
    duration: Optional[int] = None
    glucose_drop_mgdl: Optional[float] = None
    rationale: Optional[str] = None


class RecommendResponse(BaseModel):
    user_id: Optional[str] = None

    # Primary field names (matching contracts/recommend_response.json)
    diet_recommendations: Optional[List[DietRecommendation]] = []
    exercise_recommendations: Optional[List[ExerciseRecommendation]] = []

    # Legacy field names (kept so existing code doesn't break)
    diet_list: List[DietRecommendation] = []
    exercise_list: List[ExerciseRecommendation] = []
    
    # Optional debug / dynamic props
    context_warning: Optional[str] = None
    spike_risk: Optional[str] = None
    similar_users_found: Optional[int] = None   # e.g. 7 — for demo display
    current_glucose: Optional[float] = None
    # K6.3 — burnout / coach mode
    coach_mode: str = "active"            # "active" | "balanced" | "supportive"
    burnout_score: float = 0.0            # 0.0–10.0
