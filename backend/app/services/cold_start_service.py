"""
cold_start_service.py
---------------------
When a new user has < N interactions, uses cosine similarity on the training
user feature vectors to find similar users and return their top meals.
Used by diet_engine.py to boost cold-start recommendations.

Usage:
    from app.services.cold_start_service import find_similar_users
    similar_meal_ids = find_similar_users(user_feature_names, top_k=5)
"""
from pathlib import Path
from typing import List
import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
USERS_CSV = DATA_DIR / "synthetic_users.csv"
MEAL_INTS_CSV = DATA_DIR / "meal_interactions.csv"

from app.ml.feature_builder import USER_FEATURES

def _user_features_to_vector(feature_names: List[str]) -> np.ndarray:
    """Convert a list of feature name strings to a binary feature vector."""
    vec = np.zeros(len(USER_FEATURES))
    feature_index = {f: i for i, f in enumerate(USER_FEATURES)}
    for f in feature_names:
        if f in feature_index:
            vec[feature_index[f]] = 1.0
    return vec

def find_similar_users(
    user_feature_names: List[str],
    top_k: int = 5,
) -> dict:
    """
    Find top_k training users most similar to the query user.
    Returns: {
        "similar_count": int,
        "top_meal_ids": List[str]   # meal IDs preferred by similar users
    }
    """
    try:
        users_df = pd.read_csv(USERS_CSV)
        meal_ints = pd.read_csv(MEAL_INTS_CSV)

        # Build feature matrix for all training users
        from app.ml.feature_builder import user_feature_list
        user_vecs = np.array([
            _user_features_to_vector(user_feature_list(row))
            for _, row in users_df.iterrows()
        ])

        # Query vector
        query_vec = _user_features_to_vector(user_feature_names).reshape(1, -1)

        # Cosine similarity
        sims = cosine_similarity(query_vec, user_vecs)[0]
        top_indices = np.argsort(sims)[::-1][:top_k]
        similar_user_ids = users_df.iloc[top_indices]["user_id"].tolist()

        # Get top meals eaten by similar users (positive interactions only)
        top_meals = (
            meal_ints[
                meal_ints["user_id"].isin(similar_user_ids) &
                meal_ints["interaction_type"].isin(["eaten", "accepted"])
            ]
            .groupby("meal_id")["score"]
            .mean()
            .sort_values(ascending=False)
            .head(10)
            .index.tolist()
        )

        return {"similar_count": len(similar_user_ids), "top_meal_ids": top_meals}
    except Exception:
        return {"similar_count": 0, "top_meal_ids": []}
