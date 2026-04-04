# GlucoNav — Team Plan
> **For Medathon 2026 | Team Innofusion**
> Last updated: 2026-04-05

---

## Team Members

| ID | Role | Focus Area |
| -- | ---- | ---------- |
| **Member J** | ML Engineer | Recommendation Engine (LightFM, data, prediction services) |
| **Member K** | Backend Engineer | FastAPI, Vision AI, Burnout service, DB models |
| **Member L** | Frontend Engineer | Flutter UI, all screens, BLoC providers, API wiring |

---

## PHASE 0 — Shared Setup ✅
- [x] S0.1–S0.7 — Folder structure, requirements, env, SQLite, boot verified

## PHASE 1 — Recommendation Engine ✅
- [x] J1.1–J1.3 — Seed data (meals, exercises, users)
- [x] J2.1–J2.2 — ML data pipeline
- [x] J3.1–J3.2 — Model training (diet + exercise)
- [x] J4.1–J4.3 — Prediction services

## PHASE 2 — FastAPI + Flutter Base ✅
- [x] K1.1–K1.5 — DB models
- [x] K2.1–K2.3 — Pydantic schemas
- [x] K3.1–K3.7 — FastAPI routers
- [x] J0–J7 — ONT integration, onboarding, dashboard, eating sequence

## K-TRACK ✅ / L-TRACK ✅ / Phase 6.5 Integration ✅
*(See session log for details)*

---

## PHASE 6 — Demo Preparation ✅ COMPLETE

- [x] **S1.1** — `seed_demo.py` fixed (5 bugs) + verified: `demo_user_new` seeded with zero interactions
- [x] **S1.2** — `verify_demo.py` created: `demo_user_experienced` confirmed with 14-day history
- [x] **S1.3** — `DEMO_SCRIPT.md` created: 8-step script, talking points, Q&A, backup plan, key numbers
- [x] **S1.4** — Personalization delta documented: Diary tab switches between users; +54 (new) vs +18 (experienced)
- [ ] **S1.5** — Demo rehearsed; timing confirmed for judges ← **next action for team**

---

## Build Order (Final)

```
Phase 0 → Phase 1 → Phase 2
  ↓
╔══════════════════════════════════════════╗
║  K-TRACK ✅     L-TRACK ✅               ║
╚══════════════════════════════════════════╝
  ↓  Phase 6.5 Integration ✅
  ↓  Phase 6 Demo Prep ✅
S1.5 Rehearse → PRESENT TO JUDGES 🏆
```

---

## Session Log

| Session | Date       | Member | What was done |
| ------- | ---------- | ------ | ------------- |
| 1–4     | 2026-04-04 | J      | Phase 0–1: ML pipeline, model training, prediction services |
| 5–8     | 2026-04-04 | J      | Phase 2 Flutter: ONT base, onboarding, dashboard, eating sequence |
| 9       | 2026-04-05 | K+L    | TEAM_PLAN restructured for parallel tracks |
| 10      | 2026-04-05 | K      | K4: vision_service, sequence_service, vision router |
| 11      | 2026-04-05 | K      | K5–K7 + field-name normalizer bug fix |
| 12      | 2026-04-05 | L      | L6–L9: created lib/ from scratch, all screens |
| 13      | 2026-04-05 | K+L    | Phase 6.5: real API wired, CORS fix, user-switch demo buttons |
| 14      | 2026-04-05 | K+L    | **Phase 6 Demo Prep.** Fixed 5 bugs in seed_demo.py (User.id field, UserProfile fields, MealInteraction.glucose_delta, GlucoseReading.glucose_mgdl, User query field). Updated models: user.py (email/name/age/weight/height), meal.py (glucose_delta), exercise.py (soft FK), glucose.py (dual field). Fixed schemas: feedback.py (user_id), glucose.py (accepts both field names). Fixed routers: feedback.py (sets user_id), glucose.py (dual field). Created verify_demo.py (11 automated checks). Created DEMO_SCRIPT.md (8 steps, Q&A, numbers). **S1.1–S1.4 complete. Only S1.5 (rehearse) remains.** |

*Mark tasks `[/]` when starting, `[x]` when done. Always update `CONTEXT.md` after each session.*
