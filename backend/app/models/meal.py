from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
import datetime
import uuid
from app.database import Base


class Meal(Base):
    __tablename__ = "meals"

    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    cuisine = Column(String)
    meal_type = Column(String)
    gi = Column(Float)
    gl = Column(Float)
    calories = Column(Float)
    protein = Column(Float)
    carbs = Column(Float)
    fat = Column(Float)
    prep_time = Column(Integer)
    tags = Column(String)


class MealInteraction(Base):
    __tablename__ = "meal_interactions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), index=True)
    meal_id = Column(String, index=True)  # soft reference — no FK to allow CSV-only meals
    interaction_type = Column(String)     # "completed" | "skipped" | "logged"
    glucose_delta = Column(Float, nullable=True)  # post-meal glucose rise in mg/dL
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
