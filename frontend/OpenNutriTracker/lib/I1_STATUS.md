## PHASE 6.5 — Integration (K + L together — ✅ COMPLETE)

- [x] **I1.1** — Replace mock JSON with real API calls in `gluconav_api_service.dart`
  - `fetchRecommendations()` — tries `GET /recommend/{user_id}` with context params, falls back to mock
  - `analyzeImageBytes(Uint8List)` — web-compatible multipart POST to `/analyze-meal`, falls back to mock
  - `isBackendAvailable()` — health check
  - `GlucoNavApiService.userId` — static, loaded from SharedPreferences (defaults to `demo_user_experienced`)
  - `GlucoNavApiService.forceMock` — toggle for offline demo
- [x] **I1.2** — End-to-end flow: Dashboard → Scan Plate → Sequence Overlay → Start Eating → Activity Snack → Done
  - Diary tab "Demo Shortcuts" provides direct access to each screen
- [x] **I1.3** — Demo user delta: Diary tab buttons switch `demo_user_new` ↔ `demo_user_experienced`
  - new: generic recs (+54 mg/dL avg) | experienced: personalized (+18 mg/dL) = 59% improvement
- [x] **I1.4** — CORS: `allow_origins=["*"]` already in `main.py`; vision.py content-type check updated to accept `application/octet-stream` (Flutter web)
- [x] **I1.5** — Run instructions: README updated with two-terminal setup, demo script table, integration notes table

---

## PHASE 6 — Demo Preparation

- [ ] **S1.1** — Seed + verify demo_user_new (`python scripts/seed_demo.py`)
- [ ] **S1.2** — Seed + verify demo_user_experienced
- [ ] **S1.3** — 8-step demo script end-to-end
- [ ] **S1.4** — Side-by-side comparison confirmed
- [ ] **S1.5** — Demo rehearsed for judges
