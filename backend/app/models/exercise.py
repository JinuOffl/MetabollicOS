from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
import datetime
import uuid
from app.database import Base


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    type = Column(String)
    duration = Column(Integer)
    met = Column(Float)
    glucose_benefit = Column(Float)
    burnout_cost = Column(Float)
    timing = Column(String)


class ExerciseInteraction(Base):
    __tablename__ = "exercise_interactions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), index=True)
    exercise_id = Column(String, index=True)  # soft reference — no FK to allow CSV-only exercises
    interaction_type = Column(String)         # "completed" | "skipped"
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
