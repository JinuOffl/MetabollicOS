# GlucoNav — Integration Contracts
> **Read this before writing a single line of code in Phases 3–5.**  
> This document is the single source of truth for how K-Track and L-Track connect.

---

## Why This Exists

Member K (backend) and Member L (frontend) work in **completely separate folders**.  
The only connection point is the **HTTP API**. If both agree on the exact JSON shape upfront,  
integration in Phase 6.5 is just a URL swap — not a rewrite.

---

## File Ownership — Zero Overlap Guaranteed

| Member | Owns These Folders / Files | Must NEVER Touch |
|--------|---------------------------|------------------|
| **K**  | `backend/app/services/`   | Anything in `frontend/` |
|        | `backend/app/routers/`    |                  |
|        | `backend/app/schemas/`    |                  |
|        | `backend/app/models/`     |                  |
|        | `backend/scripts/`        |                  |
| **L**  | `frontend/OpenNutriTracker/lib/` | Anything in `backend/` |
|        | `frontend/OpenNutriTracker/test/` |               |

> **Shared files (read-only for both):** `contracts/*.json`, `TEAM_PLAN.md`, `CONTEXT.md`, `README.md`  
> Update docs after completing each task — but don't edit each other's source code folders.

---

## The Contracts (Exact JSON Shapes)

### Contract 1 — `POST /api/v1/analyze-meal`

**K builds this.** **L consumes this.**  
Full mock file: [`contracts/analyze_meal_response.json`](./analyze_meal_response.json)

```jsonc
// REQUEST: multipart/form-data
// Field: "image" (JPEG / PNG / WebP, max 10 MB)

// RESPONSE 200 OK:
{
  "detected_items": [
    { "label": "Idli",    "confidence": 0.92 },
    { "label": "Sambar",  "confidence": 0.76 },
    { "label": "Chutney", "confidence": 0.55 }
  ],
  "eating_sequence": [
    { "step": 1, "food": "Sambar",  "category": "Fiber", "reason": "Start with fiber-rich dal…" },
    { "step": 2, "food": "Chutney", "category": "Fat",   "reason": "Fat slows gastric emptying…" },
    { "step": 3, "food": "Idli",    "category": "Carb",  "reason": "Eat carbs last…" }
  ],
  "spike_without_order_mg_dl": 67,
  "spike_with_order_mg_dl": 24,
  "reduction_percent": 64
}

// ERROR 415: unsupported image type
// ERROR 413: image > 10 MB
// ERROR 422: no food detected with confidence ≥ 0.10
// ERROR 500: HuggingFace / Gemini failure
```

**L's rule:** Hardcode the above JSON as a Dart constant. Only swap for real call in Phase 6.5.  
**K's rule:** Your real endpoint MUST return this exact field set. Do not rename keys.

---

### Contract 2 — `GET /api/v1/recommend/{user_id}`

**K extends this (K5 adds `spike_risk`, K6 adds `coach_mode` + `burnout_score`).**  
**L consumes `spike_risk`, `coach_mode`, `burnout_score` from day one.**  
Full mock file: [`contracts/recommend_response.json`](./recommend_response.json)

```jsonc
// REQUEST: GET /api/v1/recommend/{user_id}
// Optional query params (passed by L's dashboard context):
//   ?gi=35&sleep_score=0.8&steps=3200&current_glucose=142

// RESPONSE 200 OK:
{
  "user_id": "demo_user_new",

  "diet_recommendations": [
    {
      "meal_id": "meal_001",
      "name": "Idli + Sambar",
      "cuisine": "South Indian",
      "predicted_glucose_delta": 18,        // mg/dL rise expected for this user
      "gi": 35,
      "gl": 8,
      "reason": "Low GI, high fiber. Best match for your Type 2 profile.",
      "tags": ["vegetarian", "low-gi", "breakfast"]
    }
    // ... top 3 meals
  ],

  "exercise_recommendations": [
    {
      "exercise_id": "ex_001",
      "name": "Brisk Walk",
      "type": "aerobic",
      "duration_minutes": 15,
      "met": 3.5,
      "glucose_benefit_mg_dl": -20,         // negative = lowers glucose
      "burnout_cost": 2,                    // 1–10 scale
      "reason": "Low intensity. Safe post-meal for all diabetes types.",
      "timing": "post_meal"
    }
    // ... top 2 exercises
  ],

  "context_warning": null,                  // or string like "High glucose detected"
  "spike_risk": "medium",                   // "low" | "medium" | "high"  ← K5 adds this
  "coach_mode": "active",                   // "active" | "balanced" | "supportive"  ← K6
  "burnout_score": 3                        // 0–10  ← K6
}
```

**L's rule:** Your mock JSON already has `spike_risk`, `coach_mode`, `burnout_score`. Build your UI to consume them NOW — they'll be real after integration.  
**K's rule:** K5 adds `spike_risk`. K6 adds `coach_mode` and `burnout_score`. Do not break existing fields.

---

## How L Does Mock Development (No Backend Needed)

### Step 1: Copy the mock JSON into a Dart constant

Create `lib/core/mocks/gluconav_mock_data.dart`:

```dart
// lib/core/mocks/gluconav_mock_data.dart
// DELETE this file in Phase 6.5 — replace with real API calls

const kMockAnalyzeMealResponse = {
  "detected_items": [
    {"label": "Idli",    "confidence": 0.92},
    {"label": "Sambar",  "confidence": 0.76},
    {"label": "Chutney", "confidence": 0.55},
  ],
  "eating_sequence": [
    {"step": 1, "food": "Sambar",  "category": "Fiber", "reason": "Start with fiber-rich dal to slow carb absorption."},
    {"step": 2, "food": "Chutney", "category": "Fat",   "reason": "Fat slows gastric emptying, blunting glucose spike."},
    {"step": 3, "food": "Idli",    "category": "Carb",  "reason": "Eat carbs last — spike is now significantly reduced."},
  ],
  "spike_without_order_mg_dl": 67,
  "spike_with_order_mg_dl": 24,
  "reduction_percent": 64,
};

const kMockRecommendResponse = {
  "user_id": "demo_user_new",
  "diet_recommendations": [
    {
      "meal_id": "meal_001",
      "name": "Idli + Sambar",
      "cuisine": "South Indian",
      "predicted_glucose_delta": 18,
      "gi": 35,
      "gl": 8,
      "reason": "Low GI, high fiber. Best match for your Type 2 profile.",
      "tags": ["vegetarian", "low-gi", "breakfast"],
    },
    {
      "meal_id": "meal_002",
      "name": "Moong Dal Chilla",
      "cuisine": "North Indian",
      "predicted_glucose_delta": 22,
      "gi": 38,
      "gl": 9,
      "reason": "High protein dal keeps you full and glucose stable.",
      "tags": ["vegetarian", "high-protein", "breakfast"],
    },
  ],
  "exercise_recommendations": [
    {
      "exercise_id": "ex_001",
      "name": "Brisk Walk",
      "type": "aerobic",
      "duration_minutes": 15,
      "met": 3.5,
      "glucose_benefit_mg_dl": -20,
      "burnout_cost": 2,
      "reason": "Low intensity. Safe post-meal activity for all diabetes types.",
      "timing": "post_meal",
    },
  ],
  "context_warning": null,
  "spike_risk": "medium",
  "coach_mode": "active",
  "burnout_score": 3,
};
```

### Step 2: Use a `USE_MOCK` flag in `gluconav_api_service.dart`

```dart
const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

Future<Map<String, dynamic>> analyzeMeal(File imageFile) async {
  if (kUseMock) return Map<String, dynamic>.from(kMockAnalyzeMealResponse);
  // real API call below...
  final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze-meal'));
  request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
  final response = await request.send();
  final body = await response.stream.bytesToString();
  return json.decode(body);
}

Future<Map<String, dynamic>> getRecommendations(String userId) async {
  if (kUseMock) return Map<String, dynamic>.from(kMockRecommendResponse);
  // real API call below...
  final response = await http.get(Uri.parse('$baseUrl/recommend/$userId'));
  return json.decode(response.body);
}
```

> **Phase 6.5 integration = flip `kUseMock` to `false`. That's it.**

---

## How K Verifies Contract Compliance

After completing K4/K5/K6, run:

```bash
# Start backend
cd backend && python run.py

# Test analyze-meal with a sample image
curl -X POST http://localhost:8000/api/v1/analyze-meal \
  -F "image=@tests/sample_thali.jpg"

# Test recommend
curl http://localhost:8000/api/v1/recommend/user_001
```

Then compare the output to `contracts/analyze_meal_response.json` and `contracts/recommend_response.json`.  
**All field names must match exactly.**

---

## Conflict-Free Git Rules

```
K commits to:   backend/app/services/
                backend/app/routers/
                backend/app/schemas/
                backend/scripts/

L commits to:   frontend/OpenNutriTracker/lib/

Both commit to: TEAM_PLAN.md  (mark tasks, add session log)
                CONTEXT.md    (update phase status)
```

> **Never merge or rebase each other's branches until Phase 6.5.**  
> Use separate branches: `feat/k-track` and `feat/l-track`.  
> In Phase 6.5, K merges L's branch (or vice versa) and resolves any conflicts together.

---

## Phase 6.5 Integration Checklist (for reference now)

When both tracks are done, do this in order:

1. [ ] K runs `python run.py` — backend live at `localhost:8000`
2. [ ] L sets `kUseMock = false` in `gluconav_api_service.dart`
3. [ ] L runs `flutter run -d chrome` — check CORS errors (should be none — CORS is `allow_origins=["*"]`)
4. [ ] Test `POST /analyze-meal` from the Flutter camera screen — compare to mock
5. [ ] Test `GET /recommend/{user_id}` — verify `spike_risk`, `coach_mode`, `burnout_score` display correctly
6. [ ] Fix any field mismatches (they should be zero if both followed contracts)
7. [ ] Delete `lib/core/mocks/gluconav_mock_data.dart`
8. [ ] Done ✅

---

*Last updated: 2026-04-05 | Maintained by both K and L*
