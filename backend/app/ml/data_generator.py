"""
data_generator.py
-----------------
Reads the 3 seed CSVs (meals.csv, exercises.csv, synthetic_users.csv) and
generates realistic meal_interactions and exercise_interactions for all 200
synthetic users.  Output: two CSV files saved to backend/data/:
  - meal_interactions.csv
  - exercise_interactions.csv

Usage:
    cd backend
    python app/ml/data_generator.py
"""

import os
import uuid
import random
import numpy as np
import pandas as pd
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE_DIR   = Path(__file__).resolve().parents[2]   # backend/
DATA_DIR   = BASE_DIR / "data"

MEALS_CSV  = DATA_DIR / "meals.csv"
EX_CSV     = DATA_DIR / "exercises.csv"
USERS_CSV  = DATA_DIR / "synthetic_users.csv"
OUT_MEAL_INTERACTIONS  = DATA_DIR / "meal_interactions.csv"
OUT_EX_INTERACTIONS    = DATA_DIR / "exercise_interactions.csv"

random.seed(42)
np.random.seed(42)

# ── Constants ─────────────────────────────────────────────────────────────────
INTERACTIONS_PER_USER_MEALS = (30, 50)   # min, max interactions per user
INTERACTIONS_PER_USER_EX    = (15, 25)

MEAL_TYPES_BY_HOUR = {
    "morning":   "breakfast",
    "afternoon": "lunch",
    "evening":   "snack",
    "night":     "dinner",
}

TIME_OF_DAY_OPTIONS = ["morning", "afternoon", "evening", "night"]
GLUCOSE_TRENDS      = ["rising", "stable", "falling"]


# ── Helpers ───────────────────────────────────────────────────────────────────

def normalize_score(glucose_delta: float, min_val: float = 0.0,
                    max_val: float = 100.0) -> float:
    """Map glucose_delta to a [-1, 1] score for LightFM.
    Low delta (good) → positive score; high delta (bad) → negative score.
    """
    clipped = np.clip(glucose_delta, min_val, max_val)
    normalized = (clipped - min_val) / (max_val - min_val)   # 0-1
    return round(1.0 - 2.0 * normalized, 3)                  # 1 → -1


def gi_to_base_delta(gi: float) -> float:
    """Estimate a base glucose_delta from glycemic index."""
    if gi < 40:
        return random.uniform(10, 30)
    elif gi < 60:
        return random.uniform(25, 55)
    elif gi < 75:
        return random.uniform(45, 75)
    else:
        return random.uniform(65, 95)


def apply_context_modifiers(base_delta: float, sleep_score: float,
                             avg_steps: int, current_glucose: float = 110.0,
                             glucose_trend: str = "stable") -> float:
    """Apply real-world context modifiers to the base glucose delta."""
    delta = base_delta

    # Sleep penalty: poor sleep → more insulin resistance
    if sleep_score < 0.4:
        delta += 20
    elif sleep_score < 0.6:
        delta += 10

    # Sedentary penalty
    if avg_steps < 2000:
        delta += 12
    elif avg_steps < 4000:
        delta += 6

    # Rising glucose is already spiked — compound effect
    if glucose_trend == "rising":
        delta *= 1.15
    elif glucose_trend == "falling":
        delta *= 0.85

    # Already elevated glucose
    if current_glucose > 150:
        delta *= 1.2
    elif current_glucose < 90:
        delta *= 0.85

    # Add ±15 personal noise
    delta += random.uniform(-15, 15)

    return round(max(0.0, delta), 1)


def meal_interaction_type(glucose_delta: float, meal_gi: float) -> str:
    """Determine interaction type from spike and GI."""
    if glucose_delta < 30:
        return random.choice(["accepted", "eaten", "eaten", "eaten"])
    elif glucose_delta < 55:
        return random.choice(["accepted", "eaten", "skipped"])
    else:
        return random.choice(["rejected", "skipped", "skipped"])


def simulated_current_glucose(hba1c: float) -> float:
    """Rough estimate of current glucose from HbA1c."""
    # Formula: avg_glucose ≈ 28.7 × HbA1c − 46.7
    avg = 28.7 * hba1c - 46.7
    return round(avg + random.uniform(-20, 20), 1)


# ── Main generators ───────────────────────────────────────────────────────────

def generate_meal_interactions(users_df: pd.DataFrame,
                                meals_df: pd.DataFrame) -> pd.DataFrame:
    records = []

    for _, user in users_df.iterrows():
        n = random.randint(*INTERACTIONS_PER_USER_MEALS)
        sleep_score  = float(user["sleep_quality"])
        avg_steps    = int(user["avg_daily_steps"])
        hba1c        = float(user["baseline_hba1c"])
        cuisine_pref = user["regional_cuisine"]
        diet_pref    = user["diet_preference"]

        # Filter meals relevant to this user's cuisine + diet
        relevant = meals_df.copy()
        if diet_pref in ("vegetarian", "vegan"):
            relevant = relevant[relevant["is_vegetarian"] == True]

        # Prefer cuisine-matched meals (70% chance), else any
        cuisine_meals = relevant[relevant["cuisine"] == cuisine_pref]
        other_meals   = relevant[relevant["cuisine"] != cuisine_pref]

        for _ in range(n):
            if len(cuisine_meals) > 0 and random.random() < 0.70:
                meal = cuisine_meals.sample(1).iloc[0]
            elif len(other_meals) > 0:
                meal = other_meals.sample(1).iloc[0]
            else:
                meal = relevant.sample(1).iloc[0]

            time_of_day   = random.choice(TIME_OF_DAY_OPTIONS)
            glucose_trend = random.choice(GLUCOSE_TRENDS)
            current_glucose = simulated_current_glucose(hba1c)

            base_delta  = gi_to_base_delta(float(meal["glycemic_index"]))
            delta       = apply_context_modifiers(
                base_delta, sleep_score, avg_steps,
                current_glucose, glucose_trend
            )
            itype = meal_interaction_type(delta, float(meal["glycemic_index"]))
            score = normalize_score(delta)

            records.append({
                "id":                   str(uuid.uuid4()),
                "user_id":              user["user_id"],
                "meal_id":              meal["id"],
                "interaction_type":     itype,
                "glucose_delta":        delta,
                "score":                score,
                "context_sleep_score":  round(sleep_score, 2),
                "context_steps_today":  avg_steps,
                "context_time_of_day":  time_of_day,
                "context_glucose_trend": glucose_trend,
                "current_glucose":      current_glucose,
            })

    return pd.DataFrame(records)


def generate_exercise_interactions(users_df: pd.DataFrame,
                                    exercises_df: pd.DataFrame) -> pd.DataFrame:
    records = []

    # Pre-filter high-burnout exercises
    low_burnout_ex  = exercises_df[exercises_df["burnout_cost"] <= 3]
    mid_burnout_ex  = exercises_df[exercises_df["burnout_cost"] <= 6]

    for _, user in users_df.iterrows():
        n            = random.randint(*INTERACTIONS_PER_USER_EX)
        burnout_score = int(user["burnout_score"])
        sleep_score   = float(user["sleep_quality"])
        avg_steps     = int(user["avg_daily_steps"])

        for _ in range(n):
            # Filter candidates by burnout score (mirrors exercise_engine logic)
            if burnout_score >= 7:
                pool = low_burnout_ex if len(low_burnout_ex) > 0 else exercises_df
            elif burnout_score >= 4:
                pool = mid_burnout_ex if len(mid_burnout_ex) > 0 else exercises_df
            else:
                pool = exercises_df

            ex = pool.sample(1).iloc[0]
            ex_burnout_cost = int(ex["burnout_cost"])
            ex_type         = ex["exercise_type"]

            # Determine interaction type
            if burnout_score >= 7 and ex_burnout_cost > 3:
                itype = "skipped"
            elif ex_type == "hiit" and burnout_score >= 6:
                itype = "skipped"
            elif random.random() < 0.75:
                itype = "completed"
            else:
                itype = random.choice(["skipped", "modified"])

            # Glucose benefit from exercise
            benefit_map = {"high": (-30, -15), "medium": (-15, -5), "low": (-5, 0)}
            lo, hi = benefit_map.get(ex["glucose_benefit"], (-10, 0))
            if itype in ("skipped",):
                glucose_delta_after = 0.0
            elif itype == "modified":
                glucose_delta_after = round(random.uniform(lo * 0.5, hi * 0.5), 1)
            else:
                glucose_delta_after = round(random.uniform(lo, hi), 1)

            # Adjust actual duration
            planned_dur = int(ex["duration_minutes"])
            if itype == "completed":
                actual_dur = planned_dur
            elif itype == "modified":
                actual_dur = max(1, int(planned_dur * random.uniform(0.4, 0.8)))
            else:
                actual_dur = 0

            records.append({
                "id":                     str(uuid.uuid4()),
                "user_id":                user["user_id"],
                "exercise_id":            ex["id"],
                "interaction_type":       itype,
                "duration_actual_minutes": actual_dur,
                "glucose_delta_after":    glucose_delta_after,
                "burnout_score_at_time":  burnout_score,
                "context_sleep_score":    round(sleep_score, 2),
                "context_steps_today":    avg_steps,
            })

    return pd.DataFrame(records)


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    print("[INFO] Loading seed CSVs...")
    meals_df  = pd.read_csv(MEALS_CSV)
    ex_df     = pd.read_csv(EX_CSV)
    users_df  = pd.read_csv(USERS_CSV)

    # Normalise boolean column
    meals_df["is_vegetarian"] = meals_df["is_vegetarian"].map(
        lambda x: str(x).strip().upper() == "TRUE"
    )

    print(f"   Meals: {len(meals_df)} | Exercises: {len(ex_df)} | Users: {len(users_df)}")

    print("\n[INFO] Generating meal interactions...")
    meal_ints = generate_meal_interactions(users_df, meals_df)
    meal_ints.to_csv(OUT_MEAL_INTERACTIONS, index=False)
    print(f"   [OK] meal_interactions.csv -- {len(meal_ints)} rows")

    print("\n[INFO] Generating exercise interactions...")
    ex_ints = generate_exercise_interactions(users_df, ex_df)
    ex_ints.to_csv(OUT_EX_INTERACTIONS, index=False)
    print(f"   [OK] exercise_interactions.csv -- {len(ex_ints)} rows")

    # Quick sanity stats
    print("\n[STATS] Meal interaction breakdown:")
    print(meal_ints["interaction_type"].value_counts().to_string())

    print("\n[STATS] Exercise interaction breakdown:")
    print(ex_ints["interaction_type"].value_counts().to_string())

    avg_delta = meal_ints.groupby(
        meal_ints["meal_id"].apply(
            lambda mid: meals_df.set_index("id").loc[mid, "glycemic_load"]
            if mid in meals_df["id"].values else "unknown"
        )
    )["glucose_delta"].mean().round(1)
    print("\n[STATS] Avg glucose_delta by GL category (should be low<med<high):")
    print(avg_delta.to_string())

    print("\n[DONE] data_generator.py complete. Run feature_builder.py next.")


if __name__ == "__main__":
    main()
