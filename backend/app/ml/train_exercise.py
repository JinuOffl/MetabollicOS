"""
train_exercise.py
-----------------
Trains the LightFM exercise recommendation model using WARP loss.

Usage (from backend/ directory with venv active):
    python app/ml/train_exercise.py

Output:
    app/ml/models/exercise_model.pkl   — trained LightFM model
    app/ml/models/exercise_dataset.pkl — fitted Dataset
"""

import pickle
import time
import sys
from pathlib import Path

# Essential: Add backend/ to sys.path so 'app' is importable
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE_DIR   = Path(__file__).resolve().parents[2]   # backend/
MODELS_DIR = BASE_DIR / "app" / "ml" / "models"
MODELS_DIR.mkdir(parents=True, exist_ok=True)

MODEL_PATH   = MODELS_DIR / "exercise_model.pkl"
DATASET_PATH = MODELS_DIR / "exercise_dataset.pkl"

# ── Hyperparameters ────────────────────────────────────────────────────────────
NO_COMPONENTS = 32
LOSS          = "logistic"
EPOCHS        = 50
NUM_THREADS   = 1  # Standard for Windows without OpenMP to prevent crashes
RANDOM_STATE  = 42


def train() -> None:
    print("[INFO] Loading exercise feature matrices …")
    t0 = time.time()

    from lightfm import LightFM
    from lightfm.evaluation import auc_score

    from app.ml.feature_builder import build_exercise_data

    (
        dataset,
        interactions,
        weights,
        user_features_matrix,
        ex_features_matrix,
        ex_df,
        users_df,
    ) = build_exercise_data()

    print(
        f"  Users: {len(users_df)} | Exercises: {len(ex_df)} | "
        f"Positive interactions: {interactions.nnz} | "
        f"Elapsed: {time.time() - t0:.1f}s"
    )

    # ── Model ──────────────────────────────────────────────────────────────────
    print(
        f"\n[INFO] Training LightFM (loss={LOSS}, components={NO_COMPONENTS}, epochs={EPOCHS}) …"
    )
    model = LightFM(
        no_components=NO_COMPONENTS,
        loss=LOSS,
        learning_rate=0.05,
        item_alpha=1e-6,
        user_alpha=1e-6,
        random_state=RANDOM_STATE,
    )

    t1 = time.time()
    try:
        model.fit(
            interactions=interactions,
            sample_weight=weights,
            user_features=user_features_matrix,
            item_features=ex_features_matrix,
            epochs=EPOCHS,
            num_threads=NUM_THREADS,
            verbose=True,  # Increased verbosity
        )
    except Exception as e:
        print(f"\n[ERROR] Training failed: {e}")
        import traceback
        traceback.print_exc()
        return

    elapsed = time.time() - t1
    print(f"  Training done in {elapsed:.1f}s")

    # ── Evaluation ────────────────────────────────────────────────────────────
    print("[INFO] Computing AUC on training set …")
    train_auc = auc_score(
        model,
        interactions,
        user_features=user_features_matrix,
        item_features=ex_features_matrix,
        num_threads=NUM_THREADS,
    ).mean()
    print(f"  Train AUC: {train_auc:.4f}  (>0.70 is good)")

    # ── Save ──────────────────────────────────────────────────────────────────
    print(f"\n[INFO] Saving model to {MODEL_PATH} …")
    with open(MODEL_PATH, "wb") as f:
        pickle.dump(model, f, protocol=pickle.HIGHEST_PROTOCOL)

    print(f"[INFO] Saving dataset to {DATASET_PATH} …")
    with open(DATASET_PATH, "wb") as f:
        pickle.dump(dataset, f, protocol=pickle.HIGHEST_PROTOCOL)

    print(f"\n[DONE] Exercise model saved.  Total time: {time.time() - t0:.1f}s")
    print(f"       → {MODEL_PATH}")
    print(f"       → {DATASET_PATH}")


if __name__ == "__main__":
    train()
