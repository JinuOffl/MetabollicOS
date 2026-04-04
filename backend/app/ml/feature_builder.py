"""
feature_builder.py
------------------
Builds LightFM-compatible sparse feature matrices for users, meals,
and exercises.  Called by both train_diet.py and train_exercise.py.

Exports:
    build_diet_data()     → (dataset, interactions, weights,
                             user_features_matrix, meal_features_matrix)
    build_exercise_data() → (dataset, interactions, weights,
                             user_features_matrix, ex_features_matrix)
    USER_FEATURES, MEAL_FEATURES, EXERCISE_FEATURES (feature name lists)

Usage:
    from app.ml.feature_builder import build_diet_data, build_exercise_data
"""

import json
import ast
from pathlib import Path

import numpy as np
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE_DIR  = Path(__file__).resolve().parents[2]   # backend/
DATA_DIR  = BASE_DIR / "data"

MEALS_CSV          = DATA_DIR / "meals.csv"
EX_CSV             = DATA_DIR / "exercises.csv"
USERS_CSV          = DATA_DIR / "synthetic_users.csv"
MEAL_INTS_CSV      = DATA_DIR / "meal_interactions.csv"
EX_INTS_CSV        = DATA_DIR / "exercise_interactions.csv"

# ── Feature name lists (must be stable — used at training AND predict time) ───

USER_FEATURES = [
    # diabetes type
    "diabetes_type:type1", "diabetes_type:type2",
    "diabetes_type:prediabetes", "diabetes_type:gdm",
    # diet
    "diet:vegetarian", "diet:vegan", "diet:non_vegetarian",
    # cuisine
    "cuisine:south_indian", "cuisine:north_indian", "cuisine:west_indian",
    # age band
    "age:20s", "age:30s", "age:40s", "age:50s_plus",
    # HbA1c control
    "hba1c:controlled",    # < 7.5
    "hba1c:moderate",      # 7.5 – 9.0
    "hba1c:uncontrolled",  # > 9.0
    # ThinFat phenotype
    "thinfat:yes", "thinfat:no",
    # activity level
    "activity:sedentary", "activity:light",
    "activity:moderate",  "activity:active",
]

MEAL_FEATURES = [
    # glycemic index band
    "gi:low",    # < 55
    "gi:medium", # 55 – 70
    "gi:high",   # > 70
    # glycemic load label
    "gl:low", "gl:medium", "gl:high",
    # protein
    "protein:low",    # < 10 % calories
    "protein:medium", # 10 – 20 %
    "protein:high",   # > 20 %
    # fiber
    "fiber:low",    # < 3 g
    "fiber:medium", # 3 – 6 g
    "fiber:high",   # > 6 g
    # cuisine
    "cuisine:south_indian", "cuisine:north_indian", "cuisine:west_indian",
    # meal type
    "meal_type:breakfast", "meal_type:lunch",
    "meal_type:dinner",    "meal_type:snack",
    # diet
    "is_vegetarian:yes", "is_vegetarian:no",
    # prep time
    "prep:quick", "prep:moderate", "prep:long",
]

EXERCISE_FEATURES = [
    # type
    "type:walk", "type:yoga", "type:strength",
    "type:hiit", "type:breathing",
    # intensity
    "intensity:very_low", "intensity:low",
    "intensity:medium",   "intensity:high",
    # duration band
    "duration:micro",   # < 5 min
    "duration:short",   # 5 – 15 min
    "duration:medium",  # 15 – 30 min
    "duration:long",    # 30+ min
    # glucose benefit
    "glucose_benefit:high", "glucose_benefit:medium", "glucose_benefit:low",
    # timing
    "timing:post_meal", "timing:pre_meal",
    "timing:fasted",    "timing:anytime",
    # burnout cost band
    "burnout_cost:very_low",  # 1 – 2
    "burnout_cost:low",       # 3 – 4
    "burnout_cost:medium",    # 5 – 6
    "burnout_cost:high",      # 7 – 10
]


# ── Per-row feature extractors ─────────────────────────────────────────────────

def user_feature_list(row: pd.Series) -> list[str]:
    features = []

    features.append(f"diabetes_type:{row['diabetes_type']}")
    features.append(f"diet:{row['diet_preference']}")
    features.append(f"cuisine:{row['regional_cuisine']}")
    features.append(f"age:{row['age_band']}")

    hba1c = float(row["baseline_hba1c"])
    if hba1c < 7.5:
        features.append("hba1c:controlled")
    elif hba1c <= 9.0:
        features.append("hba1c:moderate")
    else:
        features.append("hba1c:uncontrolled")

    thinfat = str(row["thinfat_flag"]).strip().upper()
    features.append("thinfat:yes" if thinfat == "TRUE" else "thinfat:no")
    features.append(f"activity:{row['activity_level']}")

    return features


def meal_feature_list(row: pd.Series) -> list[str]:
    features = []

    gi = float(row["glycemic_index"])
    if gi < 55:
        features.append("gi:low")
    elif gi <= 70:
        features.append("gi:medium")
    else:
        features.append("gi:high")

    features.append(f"gl:{row['glycemic_load']}")

    protein = float(row["protein_pct"])
    if protein < 10:
        features.append("protein:low")
    elif protein <= 20:
        features.append("protein:medium")
    else:
        features.append("protein:high")

    fiber = float(row["fiber_g"])
    if fiber < 3:
        features.append("fiber:low")
    elif fiber <= 6:
        features.append("fiber:medium")
    else:
        features.append("fiber:high")

    features.append(f"cuisine:{row['cuisine']}")
    features.append(f"meal_type:{row['meal_type']}")

    is_veg = str(row["is_vegetarian"]).strip().upper()
    features.append("is_vegetarian:yes" if is_veg == "TRUE" else "is_vegetarian:no")
    features.append(f"prep:{row['prep_time']}")

    return features


def exercise_feature_list(row: pd.Series) -> list[str]:
    features = []

    features.append(f"type:{row['exercise_type']}")
    features.append(f"intensity:{row['intensity']}")

    dur = int(row["duration_minutes"])
    if dur < 5:
        features.append("duration:micro")
    elif dur <= 15:
        features.append("duration:short")
    elif dur <= 30:
        features.append("duration:medium")
    else:
        features.append("duration:long")

    features.append(f"glucose_benefit:{row['glucose_benefit']}")
    features.append(f"timing:{row['timing']}")

    bc = int(row["burnout_cost"])
    if bc <= 2:
        features.append("burnout_cost:very_low")
    elif bc <= 4:
        features.append("burnout_cost:low")
    elif bc <= 6:
        features.append("burnout_cost:medium")
    else:
        features.append("burnout_cost:high")

    return features


# ── Build helpers ─────────────────────────────────────────────────────────────

def _load_csvs():
    meals_df   = pd.read_csv(MEALS_CSV)
    ex_df      = pd.read_csv(EX_CSV)
    users_df   = pd.read_csv(USERS_CSV)
    meal_ints  = pd.read_csv(MEAL_INTS_CSV)
    ex_ints    = pd.read_csv(EX_INTS_CSV)
    return meals_df, ex_df, users_df, meal_ints, ex_ints


def build_diet_data():
    """
    Returns
    -------
    dataset : lightfm.data.Dataset (fitted)
    interactions : scipy sparse (n_users × n_meals)
    weights : scipy sparse  — interaction weights (score values)
    user_features_matrix : scipy sparse  (n_users × n_user_features)
    meal_features_matrix : scipy sparse  (n_meals × n_meal_features)
    meals_df : pd.DataFrame  — for downstream filtering
    users_df : pd.DataFrame  — for downstream filtering
    """
    # Lazy import so the module loads even without lightfm installed
    from lightfm.data import Dataset

    meals_df, _, users_df, meal_ints, _ = _load_csvs()

    dataset = Dataset()
    dataset.fit(
        users=users_df["user_id"].tolist(),
        items=meals_df["id"].tolist(),
        user_features=USER_FEATURES,
        item_features=MEAL_FEATURES,
    )

    # --- interaction matrix (weighted by score) ---
    (interactions, weights) = dataset.build_interactions(
        (row.user_id, row.meal_id, float(row.score))
        for row in meal_ints.itertuples()
        if row.meal_id in meals_df["id"].values
    )

    # --- user feature matrix ---
    user_feature_tuples = [
        (row["user_id"], user_feature_list(row))
        for _, row in users_df.iterrows()
    ]
    user_features_matrix = dataset.build_user_features(user_feature_tuples)

    # --- meal feature matrix ---
    meal_feature_tuples = [
        (row["id"], meal_feature_list(row))
        for _, row in meals_df.iterrows()
    ]
    meal_features_matrix = dataset.build_item_features(meal_feature_tuples)

    return (dataset, interactions, weights,
            user_features_matrix, meal_features_matrix,
            meals_df, users_df)


def build_exercise_data():
    """
    Returns
    -------
    dataset : lightfm.data.Dataset (fitted)
    interactions : scipy sparse (n_users × n_exercises)
    weights : scipy sparse
    user_features_matrix : scipy sparse
    ex_features_matrix : scipy sparse
    ex_df : pd.DataFrame
    users_df : pd.DataFrame
    """
    from lightfm.data import Dataset

    _, ex_df, users_df, _, ex_ints = _load_csvs()

    # Only use completed/modified interactions as positive signal
    positive_ints = ex_ints[ex_ints["interaction_type"].isin(["completed", "modified"])].copy()
    # Score: completed = 1.0, modified = 0.5
    positive_ints["score"] = positive_ints["interaction_type"].map(
        {"completed": 1.0, "modified": 0.5}
    )

    dataset = Dataset()
    dataset.fit(
        users=users_df["user_id"].tolist(),
        items=ex_df["id"].tolist(),
        user_features=USER_FEATURES,
        item_features=EXERCISE_FEATURES,
    )

    (interactions, weights) = dataset.build_interactions(
        (row.user_id, row.exercise_id, float(row.score))
        for row in positive_ints.itertuples()
        if row.exercise_id in ex_df["id"].values
    )

    user_feature_tuples = [
        (row["user_id"], user_feature_list(row))
        for _, row in users_df.iterrows()
    ]
    user_features_matrix = dataset.build_user_features(user_feature_tuples)

    ex_feature_tuples = [
        (row["id"], exercise_feature_list(row))
        for _, row in ex_df.iterrows()
    ]
    ex_features_matrix = dataset.build_item_features(ex_feature_tuples)

    return (dataset, interactions, weights,
            user_features_matrix, ex_features_matrix,
            ex_df, users_df)


# ── Quick diagnostic ──────────────────────────────────────────────────────────

def _print_matrix_info(name: str, matrix) -> None:
    print(f"  {name}: shape={matrix.shape}, nnz={matrix.nnz}")


if __name__ == "__main__":
    print("[INFO] Building diet (meal) feature matrices...")
    out = build_diet_data()
    dataset, interactions, weights, uf_mat, mf_mat, meals_df, users_df = out
    print(f"  Users: {len(users_df)} | Meals: {len(meals_df)}")
    _print_matrix_info("interactions", interactions)
    _print_matrix_info("user_features", uf_mat)
    _print_matrix_info("meal_features", mf_mat)

    print("\n[INFO] Building exercise feature matrices...")
    out2 = build_exercise_data()
    dataset2, ints2, wts2, uf2, ef2, ex_df, _ = out2
    print(f"  Exercises: {len(ex_df)}")
    _print_matrix_info("interactions", ints2)
    _print_matrix_info("user_features", uf2)
    _print_matrix_info("exercise_features", ef2)

    print("\n[DONE] feature_builder.py validated. Ready for train_diet.py / train_exercise.py.")
