"""
recommendation_service.py
--------------------------
Core LightFM prediction wrapper.  Loads trained models once (lazy, cached)
and exposes simple prediction helpers used by diet_engine and exercise_engine.

All model I/O lives here — the engines know nothing about pickle / LightFM internals.
"""

import pickle
from functools import lru_cache
from pathlib import Path
from typing import List, Optional

import numpy as np
import pandas as pd

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE_DIR   = Path(__file__).resolve().parents[2]   # backend/
MODELS_DIR = BASE_DIR / "app" / "ml" / "models"
DATA_DIR   = BASE_DIR / "data"

DIET_MODEL_PATH     = MODELS_DIR / "diet_model.pkl"
DIET_DATASET_PATH   = MODELS_DIR / "diet_dataset.pkl"
EX_MODEL_PATH       = MODELS_DIR / "exercise_model.pkl"
EX_DATASET_PATH     = MODELS_DIR / "exercise_dataset.pkl"

MEALS_CSV = DATA_DIR / "meals.csv"
EX_CSV    = DATA_DIR / "exercises.csv"

# Feature name lists must stay identical to feature_builder.py
from app.ml.feature_builder import (
    USER_FEATURES,
    MEAL_FEATURES,
    EXERCISE_FEATURES,
    meal_feature_list,
    exercise_feature_list,
)


# ── Lazy loaders (cached for the life of the process) ─────────────────────────

@lru_cache(maxsize=1)
def _load_diet():
    """Returns (model, dataset, meals_df)."""
    if not DIET_MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Diet model not found at {DIET_MODEL_PATH}. "
            "Run: python app/ml/train_diet.py"
        )
    with open(DIET_MODEL_PATH, "rb") as f:
        model = pickle.load(f)
    with open(DIET_DATASET_PATH, "rb") as f:
        dataset = pickle.load(f)
    meals_df = pd.read_csv(MEALS_CSV)
    return model, dataset, meals_df


@lru_cache(maxsize=1)
def _load_exercise():
    """Returns (model, dataset, ex_df)."""
    if not EX_MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Exercise model not found at {EX_MODEL_PATH}. "
            "Run: python app/ml/train_exercise.py"
        )
    with open(EX_MODEL_PATH, "rb") as f:
        model = pickle.load(f)
    with open(EX_DATASET_PATH, "rb") as f:
        dataset = pickle.load(f)
    ex_df = pd.read_csv(EX_CSV)
    return model, dataset, ex_df


# ── Cold-start user feature vector ────────────────────────────────────────────

def _build_user_feature_matrix(user_feature_names: List[str], dataset):
    """
    Build a (1 × n_user_features) sparse matrix for an unseen user,
    using only the provided feature flags.

    This leverages LightFM's content-based cold start — the user_id is set
    to user index 0 (a dummy) and overridden by the feature vector, so the
    model's latent embeddings for known users don't leak in.
    """
    # Validate / filter to known features
    known = set(USER_FEATURES)
    filtered = [f for f in user_feature_names if f in known]

    if not filtered:
        # Fallback: empty features → model uses item-side information only
        filtered = []

    # We use a valid user ID from the dataset as a placeholder container.
    # The actual ID doesn't matter because the feature vector 'filtered'
    # will define the user's representation regardless of the index.
    valid_user_id = list(dataset.mapping()[0].keys())[0]
    
    user_features = dataset.build_user_features(
        [(valid_user_id, filtered)],
        normalize=True,
    )
    return user_features


# ── Public API ────────────────────────────────────────────────────────────────

def predict_meals(
    user_feature_names: List[str],
    top_n: int = 10,
    meal_type_filter: Optional[str] = None,
    score_adjustments: Optional[dict] = None,  # {meal_id: delta_score}
) -> List[dict]:
    """
    Returns up to `top_n` meals ranked by LightFM predicted score.

    Parameters
    ----------
    user_feature_names : list of feature strings, e.g. ["diabetes_type:type2", ...]
    top_n              : number of results to return
    meal_type_filter   : "breakfast" | "lunch" | "dinner" | "snack" | None
    score_adjustments  : optional {meal_id (str): float delta} for context re-ranking

    Returns
    -------
    List of dicts: {meal_id, name, cuisine, meal_type, glycemic_index,
                    glycemic_load, is_vegetarian, score}
    """
    model, dataset, meals_df = _load_diet()
    user_features_matrix = _build_user_feature_matrix(user_feature_names, dataset)

    # Filter by meal type if requested
    candidate_meals = meals_df
    if meal_type_filter:
        candidate_meals = meals_df[meals_df["meal_type"] == meal_type_filter]
        if candidate_meals.empty:
            candidate_meals = meals_df  # fallback: ignore filter

    # Get item internal indices for candidate meals
    item_id_map = dict(dataset.mapping()[2])   # external_id → internal_idx

    items = []
    for _, row in candidate_meals.iterrows():
        ext_id = row["id"]
        if ext_id in item_id_map:
            items.append((ext_id, item_id_map[ext_id], row))

    if not items:
        return []

    # Build item feature matrix for candidates
    meal_feature_tuples = [(ext_id, meal_feature_list(row)) for ext_id, _, row in items]
    item_features_matrix = dataset.build_item_features(meal_feature_tuples, normalize=True)

    # Get user internal index (cold-start user is at index 0 in the scratch dataset)
    user_id_map = dict(dataset.mapping()[0])   # external_id → internal_idx
    cold_user_idx = 0  # any valid index; we override with user_features below

    # Score all candidate items
    internal_indices = [idx for _, idx, _ in items]
    scores = model.predict(
        user_ids=cold_user_idx,
        item_ids=np.array(internal_indices),
        user_features=user_features_matrix,
        item_features=item_features_matrix,
    )

    # Apply context adjustments
    results = []
    for (ext_id, _, row), score in zip(items, scores):
        adj = (score_adjustments or {}).get(str(ext_id), 0.0)
        results.append({
            "meal_id": str(ext_id),
            "name": row["name"],
            "cuisine": row["cuisine"],
            "meal_type": row["meal_type"],
            "glycemic_index": float(row["glycemic_index"]),
            "glycemic_load": str(row["glycemic_load"]),
            "fiber_g": float(row.get("fiber_g", 0)),
            "protein_pct": float(row.get("protein_pct", 0)),
            "is_vegetarian": bool(str(row["is_vegetarian"]).upper() == "TRUE"),
            "score": float(score) + adj,
        })

    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:top_n]


def predict_exercises(
    user_feature_names: List[str],
    top_n: int = 6,
    excluded_exercise_types: Optional[List[str]] = None,
    preferred_timing: Optional[str] = None,
    score_adjustments: Optional[dict] = None,  # {exercise_id: delta_score}
) -> List[dict]:
    """
    Returns up to `top_n` exercises ranked by LightFM predicted score.

    Parameters
    ----------
    user_feature_names        : user feature strings
    top_n                     : number of results
    excluded_exercise_types   : e.g. ["hiit", "strength"] for burnout filter
    preferred_timing          : e.g. "post_meal" → +0.15 score boost
    score_adjustments         : optional {exercise_id (str): float delta}

    Returns
    -------
    List of dicts: {exercise_id, name, exercise_type, duration_minutes,
                    glucose_benefit, burnout_cost, timing, score}
    """
    model, dataset, ex_df = _load_exercise()
    user_features_matrix = _build_user_feature_matrix(user_feature_names, dataset)

    # Filter out excluded exercise types (burnout filter)
    candidate_ex = ex_df
    if excluded_exercise_types:
        exc_lower = [t.lower() for t in excluded_exercise_types]
        candidate_ex = ex_df[~ex_df["exercise_type"].str.lower().isin(exc_lower)]
        if candidate_ex.empty:
            candidate_ex = ex_df

    item_id_map = dict(dataset.mapping()[2])

    items = []
    for _, row in candidate_ex.iterrows():
        ext_id = row["id"]
        if ext_id in item_id_map:
            items.append((ext_id, item_id_map[ext_id], row))

    if not items:
        return []

    ex_feature_tuples = [(ext_id, exercise_feature_list(row)) for ext_id, _, row in items]
    item_features_matrix = dataset.build_item_features(ex_feature_tuples, normalize=True)

    internal_indices = [idx for _, idx, _ in items]
    scores = model.predict(
        user_ids=0,
        item_ids=np.array(internal_indices),
        user_features=user_features_matrix,
        item_features=item_features_matrix,
    )

    results = []
    for (ext_id, _, row), score in zip(items, scores):
        adj = (score_adjustments or {}).get(str(ext_id), 0.0)
        # Preferred timing boost
        if preferred_timing and str(row.get("timing", "")).lower() == preferred_timing.lower():
            adj += 0.15
        results.append({
            "exercise_id": str(ext_id),
            "name": row["name"],
            "exercise_type": row["exercise_type"],
            "duration_minutes": int(row["duration_minutes"]),
            "glucose_benefit": str(row["glucose_benefit"]),
            "burnout_cost": int(row["burnout_cost"]),
            "timing": str(row["timing"]),
            "score": float(score) + adj,
        })

    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:top_n]
