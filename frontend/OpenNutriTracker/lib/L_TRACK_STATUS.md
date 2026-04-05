## ║ L-TRACK — Frontend: Phases 3–5 (Member L works independently) ║

> 💡 Use hardcoded mock JSON responses while K-Track is incomplete. Replace with real API calls in Phase 6.5.

### L6 — Sequence Navigator UI (Phase 3 — Frontend)
- [x] **L6.1** — `screens/sequence/camera_screen.dart` — image_picker (camera + gallery) → loading spinner → mock POST
- [x] **L6.2** — `screens/sequence/sequence_overlay_screen.dart` — display meal photo + numbered badges over food items
- [x] **L6.3** — Numbered step list (food name + reason per step: e.g. "1. Salad — start with fiber")
- [x] **L6.4** — Spike comparison cards ("Without order: +67 mg/dL" vs "With order: +24 mg/dL") + "Start Eating!" CTA button
- [x] **L6.5** — Wire "Scan My Plate" entry point from `gluconav_dashboard_screen.dart`

**✅ L6 Done When:** Full UI flow works with mock JSON: camera → overlay → sequence list → comparison cards

### L7 — Activity Snack UI (Phase 4 — Frontend)
- [x] **L7.1** — 20-min post-meal background timer triggered after "Log this meal" tap (use `Timer` + in-app snackbar at T+20)
- [x] **L7.2** — `screens/activity/activity_snack_screen.dart` — exercise card appears at 20-min mark (exercise name, duration, glucose benefit badge)
- [x] **L7.3** — "Done!" button → call `gluconav_api_service.logFeedback(exercise_id)` → trigger streak +1 update in BLoC
- [x] **L7.4** — Integrate `spike_risk` field from mock recommendation response to conditionally show urgency level on card

**✅ L7 Done When:** Tapping "Log meal" starts timer; at 20 min, Activity Snack screen appears with correct exercise

### L8 — Burnout Shield Frontend (Phase 5 — Frontend)
- [x] **L8.1** — Read `coach_mode` + `burnout_score` from recommendation response (mock)
- [x] **L8.2** — `active` mode: normal UI with performance badges
- [x] **L8.3** — `balanced` mode: neutral language, hide streak pressure indicators
- [x] **L8.4** — `supportive` mode: softer copy ("You're doing great 💚"), hide red warnings, show encouraging emojis
- [x] **L8.5** — Animate coach-mode chip in `gluconav_dashboard_screen.dart` app bar

**✅ L8 Done When:** Changing `coach_mode` in mock JSON visibly changes app tone across all recommendation screens

### L9 — Frontend Demo Polish (Phase 6 — Frontend)
- [x] **L9.1** — Test complete 8-step demo script flow in Chrome
- [x] **L9.2** — Trends screen: display 71% Time-in-Range + 12-day streak badge
- [x] **L9.3** — Fix any UI jank, loading states, or missing error states

**✅ L-Track Done When:** All L6–L9 tasks checked. Frontend demo flows without errors.**
