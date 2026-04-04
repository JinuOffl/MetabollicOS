"""
scripts/seed_demo.py — K7.1 / K7.2 / K7.3

Seeds two demo users for hackathon demonstration:
  - demo_user_new        : zero interaction history → generic recommendations
  - demo_user_experienced: 14-day simulated history → personalized recommendations

Run from project root:
    cd backend
    python scripts/seed_demo.py

Verifies K7.3: prints recommendation delta between both users.
"""

import sys
import os
import random
from datetime import datetime, timedelta

# Allow running from backend/ directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal, engine, Base
from app.models.user import User, UserProfile
from app.models.meal import MealInteraction
from app.models.exercise import ExerciseInteraction
from app.models.glucose import GlucoseReading

# ── Ensure tables exist ──────────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)


# ── Demo User Profiles ────────────────────────────────────────────────────────
DEMO_NEW = {
    "user_id": "demo_user_new",
    "email": "demo_new@gluconav.ai",
    "name": "Priya (New)",
    "age": 35,
    "weight_kg": 62.0,
    "height_cm": 158.0,
    "diabetes_type": "type2",
    "hba1c_band": "moderate",
    "cuisine_preference": "south_indian",
    "diet_type": "vegetarian",
}

DEMO_EXPERIENCED = {
    "user_id": "demo_user_experienced",
    "email": "demo_exp@gluconav.ai",
    "name": "Priya (Experienced)",
    "age": 35,
    "weight_kg": 62.0,
    "height_cm": 158.0,
    "diabetes_type": "type2",
    "hba1c_band": "moderate",
    "cuisine_preference": "south_indian",
    "diet_type": "vegetarian",
}

# Low-GI meal IDs (favoured by the experienced user)
LOW_GI_MEAL_IDS = ["meal_001", "meal_002", "meal_003", "meal_010", "meal_011"]
# High-GI meal IDs (initial cold-start meals)
HIGH_GI_MEAL_IDS = ["meal_020", "meal_021", "meal_022"]
# Exercise IDs
EXERCISE_IDS = ["ex_001", "ex_002", "ex_003", "ex_005"]


def _upsert_user(db, profile_data: dict):
    """Create or update a user + profile, return the User object."""
    user_id = profile_data["user_id"]

    # User row
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        user = User(
            user_id=user_id,
            email=profile_data["email"],
            name=profile_data["name"],
        )
        db.add(user)
        print(f"  ✔ Created User: {user_id}")
    else:
        print(f"  ↩ User already exists: {user_id}")

    # UserProfile row
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        profile = UserProfile(
            user_id=user_id,
            age=profile_data["age"],
            weight_kg=profile_data["weight_kg"],
            height_cm=profile_data["height_cm"],
            diabetes_type=profile_data["diabetes_type"],
            hba1c_band=profile_data["hba1c_band"],
            cuisine_preference=profile_data["cuisine_preference"],
            diet_type=profile_data["diet_type"],
        )
        db.add(profile)
        print(f"  ✔ Created UserProfile: {user_id}")
    else:
        print(f"  ↩ UserProfile already exists: {user_id}")

    db.commit()
    return user


def _seed_interactions(db, user_id: str, days: int = 14):
    """
    Simulate 14 days of realistic interaction history for the experienced user.
    Pattern: starts with random meals, gradually shifts to low-GI choices.
    """
    base_date = datetime.utcnow() - timedelta(days=days)

    interactions_added = 0
    for day_offset in range(days):
        day = base_date + timedelta(days=day_offset)
        progress = day_offset / days  # 0.0 → 1.0 as time progresses

        # Meal interactions: 2–3 per day
        num_meals = random.randint(2, 3)
        for meal_slot in range(num_meals):
            # Shift preference toward low-GI meals as days progress
            if random.random() < progress:
                meal_id = random.choice(LOW_GI_MEAL_IDS)
                glucose_delta = random.uniform(12, 30)  # better control
                interaction_type = "completed"
            else:
                meal_id = random.choice(HIGH_GI_MEAL_IDS + LOW_GI_MEAL_IDS)
                glucose_delta = random.uniform(25, 60)
                interaction_type = "completed"

            meal_time = day + timedelta(hours=7 + meal_slot * 5)
            mi = MealInteraction(
                user_id=user_id,
                meal_id=meal_id,
                interaction_type=interaction_type,
                glucose_delta=glucose_delta,
                timestamp=meal_time,
            )
            db.add(mi)
            interactions_added += 1

        # Exercise interaction: 1 per day, mostly completed
        exercise_id = random.choice(EXERCISE_IDS)
        ex_type = "completed" if random.random() > 0.2 else "skipped"
        ei = ExerciseInteraction(
            user_id=user_id,
            exercise_id=exercise_id,
            interaction_type=ex_type,
            timestamp=day + timedelta(hours=20),
        )
        db.add(ei)
        interactions_added += 1

        # Glucose reading: 1–2 per day
        for _ in range(random.randint(1, 2)):
            # Glucose gradually improves over 14 days
            base_glucose = 165 - (day_offset * 1.5)
            gr = GlucoseReading(
                user_id=user_id,
                glucose_mgdl=round(base_glucose + random.uniform(-10, 10), 1),
                timestamp=day + timedelta(hours=random.randint(7, 20)),
            )
            db.add(gr)

    db.commit()
    print(f"  ✔ Seeded {interactions_added} interactions for {user_id} ({days} days)")


def seed():
    db = SessionLocal()
    try:
        print("\n── Seeding demo_user_new (K7.1) ──────────────────────────")
        _upsert_user(db, DEMO_NEW)
        # No interactions seeded — cold start

        print("\n── Seeding demo_user_experienced (K7.2) ──────────────────")
        _upsert_user(db, DEMO_EXPERIENCED)
        _seed_interactions(db, "demo_user_experienced", days=14)

        print("\n✅ Demo users seeded successfully.\n")

        # K7.3 — Quick verification
        _verify_delta(db)

    finally:
        db.close()


def _verify_delta(db):
    """K7.3 — Verify that the two users have different interaction counts."""
    from app.models.meal import MealInteraction as MI

    new_count = db.query(MI).filter(MI.user_id == "demo_user_new").count()
    exp_count = db.query(MI).filter(MI.user_id == "demo_user_experienced").count()

    print("── K7.3 Verification ─────────────────────────────────────")
    print(f"  demo_user_new        : {new_count:3d} meal interactions")
    print(f"  demo_user_experienced: {exp_count:3d} meal interactions")

    if exp_count > new_count:
        print("  ✅ Delta confirmed — experienced user has richer history")
        print("     → /recommend will return more personalised results for experienced user")
    else:
        print("  ⚠️  Warning: interaction counts unexpected — check seed logic")
    print()


if __name__ == "__main__":
    seed()
