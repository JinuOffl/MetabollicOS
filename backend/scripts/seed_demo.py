"""
scripts/seed_demo.py — K7.1 / K7.2 / K7.3

Seeds two demo users for hackathon demonstration:
  - demo_user_new        : zero interaction history → generic recommendations
  - demo_user_experienced: 14-day simulated history → personalised recommendations

Run from the backend/ directory:
    cd backend
    python scripts/seed_demo.py

Fixes applied (Session 14):
  - User constructor: id= not user_id= ; removed non-existent email/name kwargs
  - User query: User.id not User.user_id
  - UserProfile: removed age/weight_kg/height_cm (added back to model now OK)
  - MealInteraction: glucose_delta field now exists in model
  - GlucoseReading: glucose_mgdl field added to model (was value_mgdl)
  - MealInteraction / ExerciseInteraction: soft FK (no hard DB constraint)
"""

import sys
import os
import random
from datetime import datetime, timedelta
import uuid

# Allow running from backend/ directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal, engine, Base

# Import all models so Base.metadata is populated before create_all
from app.models.user import User, UserProfile          # noqa: F401
from app.models.meal import Meal, MealInteraction      # noqa: F401
from app.models.exercise import Exercise, ExerciseInteraction  # noqa: F401
from app.models.glucose import GlucoseReading          # noqa: F401

# ── Ensure all tables exist ───────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)

# ── Demo user profiles ────────────────────────────────────────────────────────
DEMO_NEW = {
    "user_id":           "demo_user_new",
    "diabetes_type":     "type2",
    "hba1c_band":        "moderate",
    "cuisine_preference":"south_indian",
    "diet_type":         "vegetarian",
    "age":               35,
    "weight_kg":         62.0,
    "height_cm":         158.0,
}

DEMO_EXPERIENCED = {
    "user_id":           "demo_user_experienced",
    "diabetes_type":     "type2",
    "hba1c_band":        "moderate",
    "cuisine_preference":"south_indian",
    "diet_type":         "vegetarian",
    "age":               35,
    "weight_kg":         62.0,
    "height_cm":         158.0,
}

# Meal IDs matching meals.csv (soft references — no FK enforcement in SQLite)
LOW_GI_MEAL_IDS  = ["meal_001", "meal_002", "meal_003", "meal_010", "meal_011"]
HIGH_GI_MEAL_IDS = ["meal_020", "meal_021", "meal_022"]
EXERCISE_IDS     = ["ex_001",  "ex_002",  "ex_003",  "ex_005"]


# ── Helpers ───────────────────────────────────────────────────────────────────

def _upsert_user(db, profile_data: dict):
    """Create or update User + UserProfile. Returns the User row."""
    user_id = profile_data["user_id"]

    # ── User row ──────────────────────────────────────────────────────────
    # Bug fix: use id= (primary key), not user_id= (non-existent field)
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        user = User(id=user_id)   # email/name are optional — omitted for demo
        db.add(user)
        db.flush()  # ensure id is written before UserProfile FK reference
        print(f"  ✔ Created User: {user_id}")
    else:
        print(f"  ↩ User already exists: {user_id}")

    # ── UserProfile row ───────────────────────────────────────────────────
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        profile = UserProfile(
            user_id=user_id,
            diabetes_type=profile_data["diabetes_type"],
            hba1c_band=profile_data["hba1c_band"],
            cuisine_preference=profile_data["cuisine_preference"],
            diet_type=profile_data["diet_type"],
            age=profile_data.get("age"),
            weight_kg=profile_data.get("weight_kg"),
            height_cm=profile_data.get("height_cm"),
        )
        db.add(profile)
        print(f"  ✔ Created UserProfile: {user_id} "
              f"({profile_data['diabetes_type']}, {profile_data['cuisine_preference']})")
    else:
        print(f"  ↩ UserProfile already exists: {user_id}")

    db.commit()
    return user


def _seed_interactions(db, user_id: str, days: int = 14):
    """
    Simulate 14 days of realistic meal + exercise + glucose history.
    Meals shift progressively toward low-GI choices as days advance.
    """
    base_date = datetime.utcnow() - timedelta(days=days)
    interactions_added = 0

    for day_offset in range(days):
        day = base_date + timedelta(days=day_offset)
        # progress 0.0 → 1.0: user learns to prefer low-GI meals over time
        progress = day_offset / max(days - 1, 1)

        # ── 2–3 meal interactions per day ─────────────────────────────────
        num_meals = random.randint(2, 3)
        for slot in range(num_meals):
            if random.random() < progress:
                meal_id = random.choice(LOW_GI_MEAL_IDS)
                glucose_delta = random.uniform(12, 30)   # improving control
            else:
                meal_id = random.choice(HIGH_GI_MEAL_IDS + LOW_GI_MEAL_IDS)
                glucose_delta = random.uniform(30, 65)   # initial higher spikes

            mi = MealInteraction(
                user_id=user_id,
                meal_id=meal_id,
                interaction_type="completed",
                glucose_delta=round(glucose_delta, 1),
                timestamp=day + timedelta(hours=7 + slot * 5),
            )
            db.add(mi)
            interactions_added += 1

        # ── 1 exercise interaction per day ────────────────────────────────
        exercise_id = random.choice(EXERCISE_IDS)
        ei = ExerciseInteraction(
            user_id=user_id,
            exercise_id=exercise_id,
            interaction_type="completed" if random.random() > 0.2 else "skipped",
            timestamp=day + timedelta(hours=20),
        )
        db.add(ei)
        interactions_added += 1

        # ── 1–2 glucose readings per day (improving trend) ─────────────────
        for _ in range(random.randint(1, 2)):
            base_glucose = 165 - (day_offset * 1.5)   # 165 → ~144 over 14 days
            reading_val = round(base_glucose + random.uniform(-10, 10), 1)
            gr = GlucoseReading(
                user_id=user_id,
                reading_type="random",
                glucose_mgdl=reading_val,
                value_mgdl=reading_val,   # legacy alias — same value
                timestamp=day + timedelta(hours=random.randint(7, 20)),
            )
            db.add(gr)

    db.commit()
    print(f"  ✔ Seeded {interactions_added} interactions for {user_id} ({days} days)")


def _verify_delta(db):
    """K7.3 — Confirm demo_user_experienced has more history than demo_user_new."""
    new_meals = db.query(MealInteraction).filter(
        MealInteraction.user_id == "demo_user_new"
    ).count()
    exp_meals = db.query(MealInteraction).filter(
        MealInteraction.user_id == "demo_user_experienced"
    ).count()
    new_gluc = db.query(GlucoseReading).filter(
        GlucoseReading.user_id == "demo_user_new"
    ).count()
    exp_gluc = db.query(GlucoseReading).filter(
        GlucoseReading.user_id == "demo_user_experienced"
    ).count()

    print("\n── K7.3 Verification ──────────────────────────────────────────")
    print(f"  {'User':<30} {'Meals':>6}  {'Glucose readings':>18}")
    print(f"  {'-'*56}")
    print(f"  {'demo_user_new':<30} {new_meals:>6}  {new_gluc:>18}")
    print(f"  {'demo_user_experienced':<30} {exp_meals:>6}  {exp_gluc:>18}")

    if exp_meals > new_meals and exp_gluc > new_gluc:
        print("\n  ✅ Delta confirmed — experienced user has richer history.")
        print("     /recommend will return more personalised results for demo_user_experienced.")
    else:
        print("\n  ⚠️  Warning: counts look unexpected — re-run seed or check DB.")
    print()


def seed():
    db = SessionLocal()
    try:
        print("\n── Seeding demo_user_new (S1.1 / K7.1) ───────────────────────")
        _upsert_user(db, DEMO_NEW)
        # No interactions — cold-start user gets generic recommendations

        print("\n── Seeding demo_user_experienced (S1.2 / K7.2) ───────────────")
        _upsert_user(db, DEMO_EXPERIENCED)
        _seed_interactions(db, "demo_user_experienced", days=14)

        # ── demo_user_type1 ───────────────────────────────────────────────────────────
        existing_t1 = db.query(User).filter(User.id == "demo_user_type1").first()
        if not existing_t1:
            db.add(User(id="demo_user_type1"))
            db.flush()
            db.add(UserProfile(
                id=str(uuid.uuid4()),
                user_id="demo_user_type1",
                diabetes_type="type1",
                hba1c_band="uncontrolled",
                cuisine_preference="north_indian",
                diet_type="non_vegetarian",
                age=28,
                weight_kg=65.0,
                height_cm=172.0,
                gender="male",
                goal="control_glucose",
                activity_level="light",
            ))
            print("✔ Created User: demo_user_type1")
        else:
            print("✔ User already exists: demo_user_type1")
        db.commit()

        print("\n✅ Demo users seeded successfully.\n")
        _verify_delta(db)

    except Exception as exc:
        db.rollback()
        print(f"\n❌ Seeding failed: {exc}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed()
