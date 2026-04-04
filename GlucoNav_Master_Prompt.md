# GlucoNav — Complete AI Build Prompt
### Hand this entire document to any AI (Claude, Cursor, ChatGPT) to start building

---

## WHO YOU ARE & WHAT YOU ARE BUILDING

You are a senior full-stack ML engineer building **GlucoNav** — a personalized diet and exercise recommendation system for Indian diabetic patients. This is being built for **Medathon 2026 (Innofusion team)**.

GlucoNav is NOT a calorie tracker. It is a **metabolic recommendation engine** — like Netflix's recommendation system, but for blood sugar management. It learns each user's unique metabolic patterns and recommends what to eat, in what order, and what micro-exercise to do after meals to prevent glucose spikes.

The target population is **101 million Indians with diabetes**, specifically designed for:
- South Asian "ThinFat" phenotype (high insulin resistance at low BMI)
- Indian regional cuisines (South Indian, North Indian, etc.)
- Patients with basic glucometers (no expensive CGM required)

---

## CORE INNOVATION (understand this before writing any code)

### 1. Netflix-style Recommendation Engine
Two people eat the same idli-sambar. One spikes to 180 mg/dL. The other stays at 130. Why? Biology, sleep, stress, prior activity. GlucoNav uses **Matrix Factorization + User Embeddings** (LightFM library) to find each user's "Metabolic Twin" — other users with similar insulin sensitivity and food patterns — and uses their outcomes to recommend meals and exercises from Day 1.

### 2. Sequence-Aware Nutrition (Order of Eating)
Don't ban rice. Eat rice LAST. Clinical research shows eating in the order: Fiber → Protein → Carbs reduces post-meal glucose spikes by **38–73%** without changing what you eat. The app overlays a numbered eating sequence directly on the user's meal photo.

### 3. Burnout Shield
50% of diabetes apps are abandoned within months due to "Diabetes Distress." GlucoNav detects early burnout signals and switches from Strict Coach → Supportive Mode (suggests 3-min walks instead of 30-min workouts).

---

## TECH STACK (non-negotiable)

| Layer | Technology | Reason |
|---|---|---|
| Frontend | Flutter (Dart) | Single codebase for Android + iOS + Web. Demo on phone AND laptop simultaneously |
| Backend | FastAPI (Python 3.11) | Async, fast, auto-generates API docs, works perfectly with ML |
| Recommendation Engine | LightFM 1.17 | Matrix Factorization + hybrid user/item features, no scratch building needed |
| Food Vision AI | google/vit-base-patch16-224 fine-tuned OR DrishtiSharma/finetuned-ViT-IndianFood-Classification-v3 (HuggingFace) | Pre-trained on Indian food, 90%+ accuracy |
| LLM for eating sequence | google/gemini-1.5-flash via Google AI SDK (free tier) | Generates the numbered dining roadmap from detected food items |
| Database | SQLite (dev) → PostgreSQL (prod) via SQLAlchemy ORM | Start simple, scale when needed |
| ML data processing | NumPy, Pandas, SciPy | Standard |
| API comms | http package (Flutter) + Pydantic (FastAPI) | Type-safe request/response |
| State management | Riverpod (Flutter) | Clean, testable, industry standard |

### Python dependencies (backend/requirements.txt)
```
fastapi==0.111.0
uvicorn==0.30.0
lightfm==1.17
numpy==1.26.4
pandas==2.2.2
scipy==1.13.0
sqlalchemy==2.0.30
pydantic==2.7.0
python-multipart==0.0.9
pillow==10.3.0
transformers==4.41.0
torch==2.3.0
google-generativeai==0.5.4
python-dotenv==1.0.1
httpx==0.27.0
pytest==8.2.0
```

### Flutter dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.1
  riverpod: ^2.5.1
  flutter_riverpod: ^2.5.1
  image_picker: ^1.1.1
  shared_preferences: ^2.2.3
  fl_chart: ^0.68.0
  cached_network_image: ^3.3.1
  go_router: ^14.0.2
  intl: ^0.19.0
```

---

## COMPLETE FOLDER STRUCTURE

```
gluconav/
│
├── backend/                          # Python FastAPI backend
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                   # FastAPI app entry point
│   │   ├── config.py                 # Settings, env variables
│   │   ├── database.py               # SQLAlchemy setup, session
│   │   │
│   │   ├── models/                   # SQLAlchemy DB models
│   │   │   ├── __init__.py
│   │   │   ├── user.py               # User, UserProfile
│   │   │   ├── meal.py               # Meal, MealInteraction
│   │   │   ├── exercise.py           # Exercise, ExerciseInteraction
│   │   │   └── glucose.py            # GlucoseReading
│   │   │
│   │   ├── schemas/                  # Pydantic request/response schemas
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   ├── recommendation.py
│   │   │   └── feedback.py
│   │   │
│   │   ├── routers/                  # FastAPI route handlers
│   │   │   ├── __init__.py
│   │   │   ├── users.py              # POST /users, GET /users/{id}
│   │   │   ├── recommendations.py    # GET /recommend/{user_id}
│   │   │   ├── feedback.py           # POST /feedback
│   │   │   ├── meals.py              # GET /meals (catalog)
│   │   │   ├── exercises.py          # GET /exercises (catalog)
│   │   │   ├── vision.py             # POST /analyze-meal (ViT + LLM)
│   │   │   └── glucose.py            # POST /glucose-reading
│   │   │
│   │   ├── services/                 # Business logic
│   │   │   ├── __init__.py
│   │   │   ├── recommendation_service.py   # LightFM wrapper
│   │   │   ├── diet_engine.py              # Diet recommender
│   │   │   ├── exercise_engine.py          # Exercise recommender
│   │   │   ├── context_service.py          # Sleep/glucose/time context
│   │   │   ├── burnout_service.py          # Distress score calculation
│   │   │   ├── vision_service.py           # ViT food detection
│   │   │   └── sequence_service.py         # LLM eating order generation
│   │   │
│   │   └── ml/                       # ML model artifacts
│   │       ├── __init__.py
│   │       ├── train_diet.py         # Train/retrain diet LightFM model
│   │       ├── train_exercise.py     # Train/retrain exercise LightFM model
│   │       ├── data_generator.py     # Synthetic user data generation
│   │       ├── feature_builder.py    # Build LightFM feature matrices
│   │       └── models/               # Saved model files (.pkl)
│   │           ├── diet_model.pkl
│   │           └── exercise_model.pkl
│   │
│   ├── data/                         # Seed data (CSV files)
│   │   ├── meals.csv                 # 60+ Indian meals with features
│   │   ├── exercises.csv             # 30 exercises with features
│   │   └── synthetic_users.csv       # 200 simulated users for training
│   │
│   ├── tests/
│   │   ├── test_recommendation.py
│   │   └── test_api.py
│   │
│   ├── .env                          # GOOGLE_AI_KEY, DATABASE_URL
│   ├── requirements.txt
│   └── run.py                        # python run.py → starts server
│
└── frontend/                         # Flutter app
    ├── lib/
    │   ├── main.dart                 # App entry, Riverpod setup
    │   ├── router.dart               # go_router routes
    │   │
    │   ├── models/                   # Dart data models
    │   │   ├── user_profile.dart
    │   │   ├── meal_recommendation.dart
    │   │   ├── exercise_recommendation.dart
    │   │   └── glucose_reading.dart
    │   │
    │   ├── providers/                # Riverpod state providers
    │   │   ├── user_provider.dart
    │   │   ├── recommendation_provider.dart
    │   │   └── glucose_provider.dart
    │   │
    │   ├── services/                 # HTTP API calls
    │   │   ├── api_service.dart      # Base HTTP client
    │   │   ├── recommendation_service.dart
    │   │   └── vision_service.dart
    │   │
    │   └── screens/                  # UI screens
    │       ├── onboarding/
    │       │   ├── onboarding_screen.dart
    │       │   └── profile_setup_screen.dart
    │       ├── home/
    │       │   └── home_screen.dart  # Main dashboard
    │       ├── sequence/
    │       │   ├── camera_screen.dart
    │       │   └── sequence_overlay_screen.dart
    │       ├── trends/
    │       │   └── trends_screen.dart
    │       └── activity/
    │           └── activity_snack_screen.dart
    │
    ├── pubspec.yaml
    └── README.md
```

---

## DATABASE SCHEMA

### users table
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,              -- UUID
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### user_profiles table
```sql
CREATE TABLE user_profiles (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    diabetes_type TEXT NOT NULL,      -- 'type1', 'type2', 'prediabetes', 'gdm'
    age_band TEXT NOT NULL,           -- '20s', '30s', '40s', '50s_plus'
    diet_preference TEXT NOT NULL,    -- 'vegetarian', 'vegan', 'non_vegetarian'
    regional_cuisine TEXT NOT NULL,   -- 'south_indian', 'north_indian', 'west_indian'
    baseline_hba1c REAL,              -- 6.0 to 14.0
    weight_kg REAL,
    height_cm REAL,
    activity_level TEXT,              -- 'sedentary', 'light', 'moderate', 'active'
    thinfat_flag BOOLEAN DEFAULT FALSE,
    has_cgm BOOLEAN DEFAULT FALSE,
    has_glucometer BOOLEAN DEFAULT TRUE,
    goal TEXT NOT NULL                -- 'control_glucose', 'lose_weight', 'improve_hba1c'
);
```

### meals table (item catalog)
```sql
CREATE TABLE meals (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,               -- 'Idli with sambar'
    name_local TEXT,                  -- 'இட்லி சாம்பார்'
    cuisine TEXT NOT NULL,            -- 'south_indian', 'north_indian'
    meal_type TEXT NOT NULL,          -- 'breakfast', 'lunch', 'dinner', 'snack'
    glycemic_index REAL NOT NULL,     -- 0-100
    glycemic_load TEXT NOT NULL,      -- 'low', 'medium', 'high'
    protein_pct REAL,                 -- % of calories from protein
    fiber_g REAL,                     -- grams per 100g serving
    carb_pct REAL,                    -- % of calories from carbs
    fat_pct REAL,
    calories_per_100g REAL,
    prep_time TEXT,                   -- 'quick', 'moderate', 'long'
    is_vegetarian BOOLEAN DEFAULT TRUE,
    tags TEXT                         -- JSON array: ['high_protein', 'low_gi', ...]
);
```

### exercises table (item catalog)
```sql
CREATE TABLE exercises (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,               -- '3-minute brisk walk'
    exercise_type TEXT NOT NULL,      -- 'walk', 'yoga', 'strength', 'hiit', 'breathing'
    duration_minutes INTEGER NOT NULL,
    intensity TEXT NOT NULL,          -- 'very_low', 'low', 'medium', 'high'
    met_value REAL,                   -- Metabolic Equivalent of Task
    glucose_benefit TEXT NOT NULL,    -- 'high', 'medium', 'low'
    equipment_needed TEXT,            -- 'none', 'mat', 'gym'
    setting TEXT,                     -- 'indoor', 'outdoor', 'anywhere'
    timing TEXT NOT NULL,             -- 'post_meal', 'pre_meal', 'fasted', 'anytime'
    burnout_cost INTEGER NOT NULL,    -- 1-10 mental load score (1=easy, 10=hard)
    description TEXT                  -- Short instruction for the user
);
```

### meal_interactions table (training data)
```sql
CREATE TABLE meal_interactions (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    meal_id TEXT REFERENCES meals(id),
    interaction_type TEXT NOT NULL,   -- 'accepted', 'rejected', 'eaten', 'skipped'
    glucose_delta REAL,               -- actual spike in mg/dL (positive = spike)
    logged_at TIMESTAMP DEFAULT NOW(),
    context_sleep_score REAL,         -- 0.0 to 1.0 (1 = excellent sleep)
    context_steps_today INTEGER,
    context_time_of_day TEXT,         -- 'morning', 'afternoon', 'evening', 'night'
    context_glucose_trend TEXT        -- 'rising', 'stable', 'falling'
);
```

### exercise_interactions table
```sql
CREATE TABLE exercise_interactions (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    exercise_id TEXT REFERENCES exercises(id),
    interaction_type TEXT NOT NULL,   -- 'completed', 'skipped', 'modified'
    duration_actual_minutes INTEGER,
    glucose_delta_after REAL,
    logged_at TIMESTAMP DEFAULT NOW(),
    burnout_score_at_time INTEGER      -- 0-10, user's burnout at time of suggestion
);
```

### glucose_readings table
```sql
CREATE TABLE glucose_readings (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    value_mg_dl REAL NOT NULL,
    reading_type TEXT,                -- 'fasting', 'post_meal_1h', 'post_meal_2h', 'random'
    recorded_at TIMESTAMP DEFAULT NOW()
);
```

---

## SEED DATA — meals.csv (build this first, 60 rows minimum)

The CSV must have these columns:
`id, name, cuisine, meal_type, glycemic_index, glycemic_load, protein_pct, fiber_g, carb_pct, fat_pct, calories_per_100g, prep_time, is_vegetarian, tags`

### Required meals to include (with approximate GI values):

| Meal | GI | GL | Notes |
|---|---|---|---|
| Idli with sambar | 35 | low | South Indian breakfast staple |
| Plain dosa | 55 | medium | South Indian, high carb |
| Masala dosa | 58 | medium | Filling, potato inside |
| Oats upma | 42 | low | North+South, high fiber |
| Poha (flattened rice) | 70 | medium | Common breakfast |
| Ragi mudde | 38 | low | South Karnataka, low GI |
| Besan chilla | 35 | low | North Indian, high protein |
| Moong dal cheela | 32 | low | Protein-rich breakfast |
| White rice + dal | 73 | high | Common lunch |
| Brown rice + dal | 55 | medium | Better alternative |
| Dal khichdi | 45 | medium | Easy to digest |
| Rajma chawal | 28 | low | High protein, low GI |
| Chole bhature | 82 | high | Avoid for T2 patients |
| Roti (1 wheat) | 62 | medium | Standard |
| Jowar roti | 52 | medium | Better than wheat |
| Bajra roti | 54 | medium | Good for diabetes |
| Paneer bhurji + roti | 45 | low | High protein |
| Dal tadka | 25 | low | High protein |
| Palak paneer | 15 | low | Very low GI, high protein |
| Sambar | 30 | low | South Indian staple |
| Curd rice | 38 | low | South Indian, probiotic |
| Sprouts salad | 28 | low | Ideal pre-meal fiber |
| Mixed vegetable curry | 35 | low | |
| Fish curry + rice | 60 | medium | Non-veg option |
| Chicken curry + roti | 40 | low | High protein non-veg |
| Egg bhurji | 0 | low | Zero carb |
| Grilled paneer | 0 | low | Zero carb snack |
| Roasted makhana | 14 | low | Low GI snack |
| Fruit chaat (apple/pear) | 38 | low | Healthy snack |
| Masala buttermilk | 25 | low | Post-meal probiotic |

---

## SEED DATA — exercises.csv (30 rows minimum)

| id | name | type | duration_min | intensity | met | glucose_benefit | burnout_cost | timing |
|---|---|---|---|---|---|---|---|---|
| ex001 | 3-min brisk walk | walk | 3 | very_low | 3.5 | high | 1 | post_meal |
| ex002 | 10-min walk | walk | 10 | low | 3.5 | high | 2 | post_meal |
| ex003 | 30-min walk | walk | 30 | low | 3.5 | high | 4 | anytime |
| ex004 | Stair climb (2 floors) | walk | 3 | low | 4.0 | high | 2 | post_meal |
| ex005 | Chair yoga | yoga | 10 | very_low | 2.5 | medium | 1 | anytime |
| ex006 | Deep breathing (4-7-8) | breathing | 3 | very_low | 1.0 | low | 1 | post_meal |
| ex007 | Surya namaskar (5 rounds) | yoga | 10 | medium | 5.0 | high | 5 | morning |
| ex008 | Bodyweight squats (10 reps) | strength | 5 | medium | 5.0 | high | 4 | post_meal |
| ex009 | Wall push-ups (10 reps) | strength | 5 | low | 3.5 | medium | 3 | anytime |
| ex010 | HIIT (20 min) | hiit | 20 | high | 8.0 | high | 9 | pre_meal |
| ex011 | Cycling (stationary, 15 min) | hiit | 15 | medium | 6.0 | high | 6 | anytime |
| ex012 | Progressive muscle relaxation | breathing | 10 | very_low | 1.5 | low | 1 | anytime |

---

## PHASE 1 — RECOMMENDATION ENGINE (Build this first, standalone)

### Goal
A working Python script that takes a user profile and returns ranked meal + exercise recommendations. No app yet. No API yet. Just the ML logic that you can test in terminal.

### What to build in Phase 1

**File: `backend/app/ml/data_generator.py`**

Generate synthetic training data. Must produce:
- 200 synthetic users with realistic profiles (mix of T1/T2/pre, veg/nonveg, regional cuisines, age bands)
- For each user: 30–50 meal interactions with realistic glucose_delta scores
  - Low-GI meals for user → glucose_delta between +10 and +30 (good)
  - High-GI meals → glucose_delta between +40 and +90 (bad)
  - Add noise: ±15 mg/dL random variation per user
  - Sleep penalty: if sleep_score < 0.5, add +20 to all deltas
- For each user: 15–25 exercise interactions
  - Post-meal walk → glucose_delta_after between -15 and -30 (good)
  - Skipped → 0 benefit
  - HIIT when burnout_score > 7 → interaction_type = 'skipped'

**File: `backend/app/ml/feature_builder.py`**

Build LightFM feature matrices:
```python
# User features (collected at onboarding)
USER_FEATURES = [
    'diabetes_type:type1', 'diabetes_type:type2', 'diabetes_type:prediabetes',
    'diet:vegetarian', 'diet:vegan', 'diet:non_vegetarian',
    'cuisine:south_indian', 'cuisine:north_indian', 'cuisine:west_indian',
    'age:20s', 'age:30s', 'age:40s', 'age:50s_plus',
    'hba1c:controlled',   # < 7.5
    'hba1c:moderate',     # 7.5 - 9.0
    'hba1c:uncontrolled', # > 9.0
    'thinfat:yes', 'thinfat:no',
    'activity:sedentary', 'activity:light', 'activity:moderate'
]

# Meal item features (from meals.csv)
MEAL_FEATURES = [
    'gi:low',       # GI < 55
    'gi:medium',    # GI 55-70
    'gi:high',      # GI > 70
    'gl:low', 'gl:medium', 'gl:high',
    'protein:low',  # < 10% calories
    'protein:medium', 'protein:high',
    'fiber:low',    # < 3g
    'fiber:medium', 'fiber:high',
    'cuisine:south_indian', 'cuisine:north_indian', 'cuisine:west_indian',
    'meal_type:breakfast', 'meal_type:lunch', 'meal_type:dinner', 'meal_type:snack',
    'is_vegetarian:yes', 'is_vegetarian:no',
    'prep:quick', 'prep:moderate', 'prep:long'
]

# Exercise item features
EXERCISE_FEATURES = [
    'type:walk', 'type:yoga', 'type:strength', 'type:hiit', 'type:breathing',
    'intensity:very_low', 'intensity:low', 'intensity:medium', 'intensity:high',
    'duration:micro',   # < 5 min
    'duration:short',   # 5-15 min
    'duration:medium',  # 15-30 min
    'duration:long',    # 30+ min
    'glucose_benefit:high', 'glucose_benefit:medium', 'glucose_benefit:low',
    'timing:post_meal', 'timing:pre_meal', 'timing:anytime',
    'burnout_cost:very_low',  # 1-2
    'burnout_cost:low',       # 3-4
    'burnout_cost:medium',    # 5-6
    'burnout_cost:high'       # 7-10
]
```

**File: `backend/app/ml/train_diet.py`**

```python
from lightfm import LightFM
from lightfm.data import Dataset
from lightfm.evaluation import precision_at_k, auc_score
import pickle

def train_diet_model(interactions_df, user_features_df, meal_features_df):
    dataset = Dataset()
    dataset.fit(
        users=interactions_df['user_id'].unique(),
        items=interactions_df['meal_id'].unique(),
        user_features=USER_FEATURES,
        item_features=MEAL_FEATURES
    )
    
    # Build interaction matrix
    # Positive interactions (accepted, low spike) = 1
    # Negative interactions (rejected, high spike) = -1 (implicit feedback)
    (interactions, weights) = dataset.build_interactions(
        [(row.user_id, row.meal_id, row.score)  # score = normalized -1 to 1
         for row in interactions_df.itertuples()]
    )
    
    # Hybrid model: uses both collaborative (matrix) and content (features)
    model = LightFM(
        loss='warp',          # WARP = best for implicit feedback ranking
        no_components=32,     # Embedding dimensions
        learning_rate=0.05,
        item_alpha=1e-6,      # L2 regularization
        user_alpha=1e-6
    )
    
    model.fit(
        interactions,
        user_features=user_features_matrix,
        item_features=item_features_matrix,
        epochs=50,
        num_threads=4,
        verbose=True
    )
    
    # Save model
    with open('app/ml/models/diet_model.pkl', 'wb') as f:
        pickle.dump({'model': model, 'dataset': dataset}, f)
    
    return model
```

**File: `backend/app/services/diet_engine.py`**

The prediction service. Given a user_id + context, returns top-N meals ranked:

```python
def get_diet_recommendations(
    user_id: str,
    meal_type: str,       # 'breakfast', 'lunch', 'dinner', 'snack'
    sleep_score: float,   # 0.0-1.0
    glucose_current: float,   # current reading mg/dL
    glucose_trend: str,   # 'rising', 'stable', 'falling'
    n_recommendations: int = 3
) -> list[MealRecommendation]:

    # 1. Get user's internal LightFM index
    user_idx = dataset.mapping()[0][user_id]
    
    # 2. Get all meal item indices for this meal_type
    candidate_meal_ids = filter_meals_by_type(meal_type)
    candidate_item_idxs = [dataset.mapping()[2][mid] for mid in candidate_meal_ids]
    
    # 3. Score all candidates
    scores = model.predict(
        user_ids=user_idx,
        item_ids=candidate_item_idxs,
        user_features=user_features_matrix,
        item_features=item_features_matrix
    )
    
    # 4. Apply context adjustments (rule layer on top of LightFM)
    if sleep_score < 0.4:
        # Bad sleep → boost high-fiber, high-protein items, penalize high-GI
        scores = apply_sleep_penalty(scores, candidate_meal_ids)
    
    if glucose_trend == 'rising':
        # Already rising → heavily penalize high-GI meals
        scores = apply_glucose_penalty(scores, candidate_meal_ids)
    
    # 5. Return top-N with explanation
    top_indices = np.argsort(-scores)[:n_recommendations]
    return [build_recommendation(idx, scores[idx]) for idx in top_indices]
```

**File: `backend/app/services/exercise_engine.py`**

Same structure as diet_engine.py but:
- Items are exercises not meals
- Context: burnout_score (0-10) filters out high-burnout exercises before scoring
- Post-meal context: boost short-duration post-meal walks
- If burnout_score >= 7: only show exercises with burnout_cost <= 3

```python
def get_exercise_recommendations(
    user_id: str,
    trigger: str,           # 'post_meal', 'scheduled', 'spike_rising'
    burnout_score: int,     # 0-10
    glucose_delta: float,   # current spike if post-meal
    n_recommendations: int = 3
) -> list[ExerciseRecommendation]:
    
    # Filter by burnout before LightFM scoring
    if burnout_score >= 7:
        candidate_ids = [ex for ex in all_exercises if ex.burnout_cost <= 3]
    elif burnout_score >= 4:
        candidate_ids = [ex for ex in all_exercises if ex.burnout_cost <= 6]
    else:
        candidate_ids = all_exercises
    
    # Filter by trigger
    if trigger == 'post_meal':
        candidate_ids = [ex for ex in candidate_ids if ex.timing in ['post_meal', 'anytime']]
    
    # LightFM scoring
    scores = model.predict(user_ids=user_idx, item_ids=candidate_item_idxs, ...)
    
    # Return top-N
    ...
```

### Phase 1 Test
Run `python backend/app/ml/train_diet.py` → model trains, saves to .pkl
Run `python backend/test_recommend.py` with a test user → prints top-3 meals and exercises
**No API, no Flutter, no vision — just pure Python ML working correctly.**

---

## PHASE 2 — FASTAPI BACKEND + FLUTTER APP

### Goal
Connect the working recommendation engine to a REST API, then build the Flutter app to consume it.

### Phase 2A — FastAPI wrapper (build this first)

**File: `backend/app/main.py`**
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import users, recommendations, feedback, meals, exercises, glucose

app = FastAPI(title="GlucoNav API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Flutter web needs this
    allow_methods=["*"],
    allow_headers=["*"]
)

app.include_router(users.router, prefix="/api/v1")
app.include_router(recommendations.router, prefix="/api/v1")
app.include_router(feedback.router, prefix="/api/v1")
app.include_router(meals.router, prefix="/api/v1")
app.include_router(exercises.router, prefix="/api/v1")
app.include_router(glucose.router, prefix="/api/v1")
```

**Critical API endpoints to implement:**

```
POST /api/v1/users/onboard
Body: { name, diabetes_type, age_band, diet_preference, regional_cuisine, 
        baseline_hba1c, weight_kg, height_cm, activity_level, goal }
Returns: { user_id, message: "Profile created" }

GET /api/v1/recommend/{user_id}
Query params: meal_type, sleep_score, glucose_current, glucose_trend, burnout_score
Returns: {
    diet: [
        { meal_id, name, cuisine, predicted_spike_mg_dl, score, reason, sequence_tip },
        ...
    ],
    exercise: [
        { exercise_id, name, duration_minutes, description, predicted_glucose_drop, reason },
        ...
    ],
    context_warning: "Your sleep was poor — high-fiber options ranked higher today"
}

POST /api/v1/feedback
Body: { user_id, item_id, item_type, interaction_type, glucose_delta }
Returns: { status: "recorded" }

POST /api/v1/glucose-reading
Body: { user_id, value_mg_dl, reading_type }
Returns: { user_id, latest_reading, trend }

GET /api/v1/meals?cuisine=south_indian&meal_type=breakfast
Returns: list of meals (full catalog browsing)
```

### Phase 2B — Flutter App

**Screen 1: Onboarding (`onboarding_screen.dart`)**
Multi-step form collecting user profile. Steps:
1. Name + diabetes type selector (T1/T2/Pre/GDM cards)
2. Diet preference (Veg/Vegan/Non-veg)
3. Regional cuisine preference (South/North/West Indian)
4. Goals (Control glucose / Lose weight / Improve HbA1c)
5. Baseline HbA1c input + activity level
On complete → POST /api/v1/users/onboard → save user_id to SharedPreferences

**Screen 2: Home Dashboard (`home_screen.dart`)**

When loaded:
1. Read user_id from SharedPreferences
2. Ask user quick context questions (or read from device):
   - "How was your sleep?" (slider 1-5)
   - "What meal are you planning?" (breakfast/lunch/dinner/snack)
3. Call GET /api/v1/recommend/{user_id} with context
4. Display:
   - Top 3 meal recommendation cards (name, predicted spike badge, reason text)
   - Top 2 exercise recommendation cards (name, duration, glucose drop badge)
   - Context warning banner if applicable

**Meal recommendation card UI:**
```
┌─────────────────────────────────────┐
│ Idli with Sambar          +18 mg/dL │  ← green badge
│ South Indian · Breakfast            │
│ "Low GI · Your Metabolic Twin       │
│  loved this · High fiber"           │
│                    [Log this meal →]│
└─────────────────────────────────────┘
```

**Exercise recommendation card UI:**
```
┌─────────────────────────────────────┐
│ 3-min walk                -20 mg/dL │  ← teal badge
│ After your meal · Very easy         │
│ "Walk to the kitchen and back.      │
│  Will flatten your spike by 20%"    │
│                         [Done! ✓]  │
└─────────────────────────────────────┘
```

**Screen 3: Trends (`trends_screen.dart`)**
- Line chart (fl_chart): last 7 days glucose readings
- "Time in Range" percentage (goal: >70% in 70-180 mg/dL)
- Consistency streak counter
- Last 5 meal interactions with outcome badges

**Color scheme (GlucoNav brand):**
- Primary: #0F6E56 (deep teal green — health, trust)
- Secondary: #1D9E75 (lighter teal)
- Background: #FFFFFF / #F8FFFE (near white, slight green tint)
- Spike bad: #E24B4A (red)
- Spike good: #0F6E56 (green)
- Text primary: #1A1A2E
- Text secondary: #6B7280

---

## PHASE 3 — ORDER OF EATING (Sequence Navigator)

### Goal
User taps "Scan My Plate" → camera opens → photo taken → ViT detects food items → LLM generates numbered eating sequence → app overlays numbered labels on the photo.

### Phase 3A — Vision service (`backend/app/services/vision_service.py`)

Use HuggingFace Transformers to load the ViT model:

```python
from transformers import ViTForImageClassification, ViTImageProcessor
import torch
from PIL import Image

MODEL_NAME = "DrishtiSharma/finetuned-ViT-IndianFood-Classification-v3"

def load_vision_model():
    processor = ViTImageProcessor.from_pretrained(MODEL_NAME)
    model = ViTForImageClassification.from_pretrained(MODEL_NAME)
    model.eval()
    return processor, model

def detect_food_items(image_bytes: bytes) -> list[dict]:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    inputs = processor(images=image, return_tensors="pt")
    
    with torch.no_grad():
        outputs = model(**inputs)
    
    # Get top-5 predictions with confidence scores
    logits = outputs.logits
    probs = torch.softmax(logits, dim=-1)
    top5 = torch.topk(probs, 5)
    
    results = []
    for score, idx in zip(top5.values[0], top5.indices[0]):
        label = model.config.id2label[idx.item()]
        results.append({
            "food_name": label,
            "confidence": round(score.item(), 3),
            "food_type": classify_macro_type(label)  # 'fiber', 'protein', 'carb', 'fat'
        })
    
    return [r for r in results if r['confidence'] > 0.15]  # Filter low-confidence

def classify_macro_type(food_name: str) -> str:
    # Rule-based macro classification
    fiber_foods = ['salad', 'vegetable', 'sambar', 'rasam', 'spinach', 'broccoli']
    protein_foods = ['dal', 'paneer', 'chicken', 'fish', 'egg', 'chole', 'rajma']
    carb_foods = ['rice', 'roti', 'bread', 'idli', 'dosa', 'naan', 'poha']
    fat_foods = ['ghee', 'butter', 'cream', 'oil']
    
    food_lower = food_name.lower()
    if any(f in food_lower for f in fiber_foods): return 'fiber'
    if any(f in food_lower for f in protein_foods): return 'protein'
    if any(f in food_lower for f in carb_foods): return 'carb'
    if any(f in food_lower for f in fat_foods): return 'fat'
    return 'unknown'
```

**API endpoint: `POST /api/v1/analyze-meal`**
```
Input: multipart form with image file
Output: {
    detected_items: [
        { food_name: "Rice", food_type: "carb", confidence: 0.94 },
        { food_name: "Dal tadka", food_type: "protein", confidence: 0.87 },
        { food_name: "Cucumber salad", food_type: "fiber", confidence: 0.71 }
    ],
    eating_sequence: [
        { order: 1, food_name: "Cucumber salad", reason: "Fiber first — triggers GLP-1, slows gastric emptying" },
        { order: 2, food_name: "Dal tadka", reason: "Protein second — further blunts glucose rise" },
        { order: 3, food_name: "Rice", reason: "Carbs last — glucose spike reduced 38–73%" }
    ],
    predicted_spike_with_sequence: "+24 mg/dL",
    predicted_spike_without_sequence: "+67 mg/dL",
    spike_reduction_pct: 64
}
```

### Phase 3B — LLM sequence generation (`backend/app/services/sequence_service.py`)

```python
import google.generativeai as genai

genai.configure(api_key=os.environ["GOOGLE_AI_KEY"])
model = genai.GenerativeModel('gemini-1.5-flash')

def generate_eating_sequence(detected_items: list[dict], user_profile: dict) -> dict:
    items_text = "\n".join([f"- {item['food_name']} (type: {item['food_type']})" 
                            for item in detected_items])
    
    prompt = f"""You are a diabetes nutrition expert. A patient with {user_profile['diabetes_type']} 
has these food items on their plate:

{items_text}

Clinical evidence shows eating in the order Fiber → Protein → Carbohydrates reduces 
post-meal glucose spikes by 38-73% by triggering early GLP-1 release.

Generate a personalized eating sequence for this plate. Return ONLY valid JSON:
{{
    "sequence": [
        {{
            "order": 1,
            "food_name": "exact food name from the list",
            "macro_category": "fiber|protein|carb|fat",
            "instruction": "short action instruction (max 8 words)",
            "reason": "one sentence clinical reason"
        }}
    ],
    "summary": "one encouraging sentence about this plate"
}}"""
    
    response = model.generate_content(prompt)
    return json.loads(response.text)
```

### Phase 3C — Flutter Sequence Navigator Screen

**`camera_screen.dart`**
- Uses `image_picker` package to open camera or gallery
- On image selected → shows loading state → calls POST /api/v1/analyze-meal
- On response → navigate to sequence_overlay_screen.dart

**`sequence_overlay_screen.dart`**
The WOW moment. Display:
1. The meal photo at the top
2. Overlay numbered circles (1, 2, 3...) as colored badges near each detected food
3. Below the photo: numbered list with food name + reason
4. Bottom: two stat cards side by side:
   - "Without sequence: +67 mg/dL" (red)
   - "With this order: +24 mg/dL" (green)
5. A "Start eating!" button that starts a timer

Implementation note: For the hackathon, position the numbered badges at approximate regions of the photo (top-left, center, bottom-right etc.) rather than pixel-precise object detection bounding boxes — the judge sees the concept clearly.

---

## PHASE 4 — POST-MEAL ENGINE (Activity Snack)

### Goal
20 minutes after user logs a meal → check if glucose is rising → send targeted exercise suggestion → user completes it → glucose spike flattens.

### Implementation

**Backend: `backend/app/services/context_service.py`**

```python
def calculate_spike_risk(
    meal_gi: float,
    meal_portion_size: str,   # 'small', 'medium', 'large'
    sleep_score: float,
    steps_today: int,
    current_glucose: float
) -> dict:
    
    # Simplified spike prediction formula for hackathon
    base_spike = meal_gi * 0.6  # Rough estimate
    
    # Modifiers
    if sleep_score < 0.4: base_spike *= 1.35  # Bad sleep = more resistance
    if steps_today < 2000: base_spike *= 1.15  # Sedentary
    if current_glucose > 140: base_spike *= 1.2  # Already elevated
    
    return {
        "predicted_spike": round(base_spike, 1),
        "risk_level": "high" if base_spike > 50 else "medium" if base_spike > 30 else "low",
        "intervention_needed": base_spike > 35
    }
```

**Flutter: 20-min post-meal timer**
- After user taps "Log this meal" → start background timer
- At 20 minutes → show ActivitySnack notification/card
- Card shows: exercise name, duration, predicted glucose drop
- User taps "Done" → log exercise_interaction → update streak

---

## PHASE 5 — BURNOUT SHIELD

### Burnout score calculation (`backend/app/services/burnout_service.py`)

For the hackathon, burnout score is calculated from:

```python
def calculate_burnout_score(user_id: str, db: Session) -> int:
    # Get last 7 days of user behavior
    recent_interactions = get_recent_interactions(user_id, days=7)
    
    score = 0
    
    # Rejection rate (skipping recommendations)
    rejection_rate = count_skipped / count_total
    if rejection_rate > 0.5: score += 3
    elif rejection_rate > 0.3: score += 1
    
    # Streak breaks
    if days_since_last_log > 2: score += 2
    
    # High spike frequency (not improving)
    recent_spikes = [r.glucose_delta for r in recent_interactions if r.glucose_delta > 60]
    if len(recent_spikes) > 3: score += 2
    
    # App open frequency (proxy for engagement)
    # If app not opened in 2+ days: +2
    if days_since_last_open > 2: score += 2
    
    return min(score, 10)  # Cap at 10

def get_coach_mode(burnout_score: int) -> str:
    if burnout_score >= 7: return "supportive"   # Only micro-exercises, positive framing
    if burnout_score >= 4: return "balanced"     # Mix of coaching + support
    return "active"                               # Full coaching mode
```

The `coach_mode` is returned with every `/recommend` response and Flutter uses it to adjust UI tone (supportive mode = softer language, encouraging emojis, no red warning colors).

---

## IMPORTANT IMPLEMENTATION NOTES

### No CGM Required
The system works with manual glucometer readings. User manually inputs glucose values via a simple number input. If no recent reading: use diabetes-type-based defaults (T2 fasting average = 130 mg/dL).

### Cold Start (New User) Solution
When a new user has zero interaction history, LightFM falls back to their feature vector (diabetes type, diet preference, cuisine). This is the "Metabolic Twin" mechanism — it finds the closest users in the existing 200-user synthetic dataset and uses their patterns. You don't need to do anything special — LightFM handles this automatically when you provide user_features at predict time.

### Model Retraining (Hackathon version)
Run `python backend/app/ml/train_diet.py` after adding new interactions. For the demo: pre-train with 200 synthetic users, show the "before" state (generic recommendations) and "after" state (personalized after simulated 2 weeks of interactions). Use two pre-seeded user profiles for this demo.

### Demo User Setup
Create two users before the presentation:
- `demo_user_new`: zero interaction history → gets generic recommendations
- `demo_user_experienced`: 14-day simulated history → gets highly personalized recommendations

Show judges the difference in recommendations for the same meal_type query. That is the "it learns you" proof point.

### Environment Variables (.env)
```
GOOGLE_AI_KEY=your_gemini_api_key_here
DATABASE_URL=sqlite:///./gluconav.db
MODEL_PATH=app/ml/models/
DEBUG=True
```

### Running the project
```bash
# Backend
cd backend
pip install -r requirements.txt
python app/ml/data_generator.py    # Generate synthetic data
python app/ml/train_diet.py        # Train diet model
python app/ml/train_exercise.py    # Train exercise model
python run.py                      # Start FastAPI on localhost:8000

# Frontend
cd frontend
flutter pub get
flutter run                        # Runs on connected device or emulator
# For web (laptop demo): flutter run -d chrome
```

---

## WHAT TO BUILD IN EACH SESSION

| Session | What you complete | How you know it works |
|---|---|---|
| Session 1 | meals.csv + exercises.csv seed data + data_generator.py | 200 user CSV file generated |
| Session 2 | feature_builder.py + train_diet.py + train_exercise.py | Model trains, .pkl saved, precision@10 > 0.3 |
| Session 3 | diet_engine.py + exercise_engine.py prediction logic | Terminal: user_id → top-3 meals printed |
| Session 4 | FastAPI routers + all endpoints | Swagger UI at /docs shows all routes, /recommend returns JSON |
| Session 5 | Flutter onboarding + home screen (API call works) | App shows real recommendations from backend |
| Session 6 | Vision service (ViT) + sequence_service (Gemini) | /analyze-meal returns eating sequence JSON |
| Session 7 | Flutter sequence overlay screen | "Scan plate" → numbered overlay on photo |
| Session 8 | Post-meal timer + burnout score + trends screen | Full demo flow works end-to-end |

---

## DEMO SCRIPT (for judges)

1. Open app → show onboarding (Priya, Type 2, South Indian, Vegetarian)
2. Home screen loads → shows "Idli + Sambar" as #1 recommendation with "+18 mg/dL"
3. Tap "Scan My Plate" → photograph a thali → sequence overlay appears
4. Show numbers 1, 2, 3 on the photo → "You'll reduce your spike by 64% just by eating in this order"
5. Log the meal → 20-min timer starts
6. Fast-forward (pre-demo) → Activity Snack card appears: "3-min walk → -20 mg/dL"
7. Switch to demo_user_experienced → show personalized vs generic recommendations side-by-side
8. Open Trends screen → Time-in-Range chart showing 71% → Consistency streak: 12 days

---

*Built by Team Innofusion for Medathon 2026. GlucoNav — not a tracker, a metabolic co-pilot.*
