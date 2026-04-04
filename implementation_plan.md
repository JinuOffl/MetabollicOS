# Phase 2: Integrate OpenNutriTracker as GlucoNav Frontend Base

## Background

Phase 1 (LightFM Recommendation Engine) is complete. We adopt **OpenNutriTracker (ONT)** as the Flutter base, then layer GlucoNav innovations on top.

> [!IMPORTANT]
> ONT uses **BLoC/Provider/Hive** — we keep this. No Riverpod.  
> Frontend project root: `frontend/OpenNutriTracker/`

---

## Design System — Apple Style

| Token          | Value                                          | Use                                 |
| -------------- | ---------------------------------------------- | ----------------------------------- |
| Background     | `#F5F5F7`                                      | Main canvas (Apple light gray)      |
| Surface        | `#FFFFFF`                                      | Cards, sheets                       |
| Primary Text   | `#1D1D1F`                                      | Headlines (Apple near-black)        |
| Secondary Text | `#6E6E73`                                      | Subtitles, labels                   |
| Accent         | `#0F6E56`                                      | GlucoNav teal (CTA buttons, badges) |
| Spike Red      | `#FF3B30`                                      | High spike warning (Apple red)      |
| Spike Green    | `#34C759`                                      | Good spike (Apple green)            |
| Spike Yellow   | `#FF9500`                                      | Moderate spike (Apple orange)       |
| Divider        | `#D2D2D7`                                      | Subtle separators                   |
| Font           | SF Pro-inspired → **Poppins** (already in ONT) |

**Visual rules:**
- No heavy gradients — use subtle shadows (`BoxShadow` opacity 0.06)
- Rounded corners: `BorderRadius.circular(16)` for cards, `20` for sheets
- Cards: white background on `#F5F5F7` canvas — clean depth via shadow only
- Bottom nav: translucent frosted glass style (`BackdropFilter` blur)

---

## Navigation Structure — 3 Tabs

```
┌────────────────────────────────────┐
│           App Content              │
├──────────┬───────────┬─────────────┤
│  📷      │    🏠     │    👤       │
│ Camera   │   Home    │  Profile    │
└──────────┴───────────┴─────────────┘
```

### Tab 1 — Camera (📷)
Opens a **full-screen camera/action sheet** offering:
1. 🍽️ **Scan Meal** → opens camera → ViT identifies food → logs meal → triggers Order-of-Eating sheet
2. 📊 **Log Meal Manually** → opens ONT's existing `AddMealScreen` (search / barcode)
3. 📷 **Barcode Scanner** → ONT's existing `ScannerScreen`

*Every food logged here feeds back into LightFM interaction data → better future recommendations.*

Implementation note: Camera tab uses `Navigator.push` overlay rather than a persistent screen — tapping it pushes a `ModalBottomSheet` or full-screen camera view, then returns to last tab.

### Tab 2 — Home 🏠 (main screen)

Scrollable column with **3 sections**:

#### Section 1 — Context Input Banner (existing from ONT plan)
- Compact card: Sleep quality slider (😴1–10), Current glucose field, Meal time auto-detected
- "Refresh AI Picks" button → calls `GET /api/v1/recommend/{user_id}`
- Coach mode chip (Active / Balanced / Supportive) in top-right corner

#### Section 2 — "Meals Today" 🍽️
- Section header: **"Meals Today"** with date chip right-aligned
- **Horizontal scroll row** of meal-time cards: `Breakfast → Lunch → Snack → Dinner`
- Each card (meal-time slot):
  - Top: meal icon / placeholder image (greyed if not yet logged)
  - Middle: meal name (from recommendation OR logged name)
  - Bottom: spike badge (`+18 mg/dL` in green/yellow/red pill) + `AI Pick` chip
  - State A (recommended, not logged): teal border dashed, "Suggested" label
  - State B (logged): solid white card with checkmark
  - **Last card = `+` card**: "Log a meal" teal dashed card → opens Camera tab action sheet
- Below horizontal row: small "Eating order matters ↗" link → opens `EatingSequenceSheet`

#### Section 3 — "Activity" 🏃
- Section header: **"Activity"** 
- **Horizontal scroll row** of exercise cards (no images, use `Icon` or emoji for exercise type)
  - Each card: exercise icon + name + duration badge + glucose drop badge (`−20 mg/dL`)
  - State A (recommended): teal dashed border
  - State B (done): green card with ✓
  - **Last card = `+` card**: "Log activity" → opens `AddActivityScreen` (from ONT)
- Below row: daily steps or streak counter (optional, if available from ONT)

### Tab 3 — Profile 👤

Combined **Diary + Profile** in a single scrollable screen with two sub-sections:

#### Sub-section A — Today's Diary (top)
- ONT's existing `DiaryPage` content embedded as a widget (not a separate route)
- Shows calorie summary ring + logged meal list for today
- Compact view, not full-screen

#### Sub-section B — My Profile (below diary)
- ONT's existing profile fields (name, age, weight, activity level)
- **Extended with GlucoNav fields**: Diabetes Type chip, HbA1c band, Cuisine, Diet type
- Edit button → opens editable form sheet

---

## Proposed File Changes

### Component 1 — Design Tokens

#### [MODIFY] [color_schemes.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/core/styles/color_schemes.dart)
- Override `lightColorScheme`: `background: #F5F5F7`, `surface: #FFFFFF`, `primary: #0F6E56`, `onBackground: #1D1D1F`
- Override `darkColorScheme`: matching Apple dark palette

#### [MODIFY] [pubspec.yaml](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/pubspec.yaml)
- `name: gluconav`, add `shared_preferences`

#### [MODIFY] [main.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/main.dart)
- Rename `OpenNutriTrackerApp` → `GlucoNavApp`

---

### Component 2 — Navigation Shell

#### [MODIFY] [main_screen.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/core/presentation/main_screen.dart)
- Replace ONT's existing bottom nav (Home/Diary/Profile + FAB) with **3-tab** structure
- Tab items: Camera (icon: `camera_alt`), Home (icon: `home`), Profile (icon: `person`)
- Apply frosted-glass bottom nav bar
- Camera tab: on tap → doesn't navigate to screen, instead shows `GlucoNavCameraSheet` modal
- Body: index 0 → (unused, camera is modal), index 1 → `HomeScreen`, index 2 → `ProfileDiaryScreen`

#### [NEW] [gluconav_camera_sheet.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/gluconav_camera/gluconav_camera_sheet.dart)
- `showModalBottomSheet` with 3 options: Scan Meal (camera → ViT), Log Manually, Barcode Scanner
- Scan Meal option: uses `image_picker`, POSTs to `POST /api/v1/analyze-meal`, triggers `EatingSequenceSheet`

---

### Component 3 — Home Screen

#### [NEW] [gluconav_home_screen.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/gluconav_home/gluconav_home_screen.dart)
- Scrollable `Column` with 3 sections described above
- Reads recommendations from `GlucoNavDashboardBloc`

#### [NEW] [meal_slot_card.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/gluconav_home/widgets/meal_slot_card.dart)
- Reusable card widget for each meal-time slot (Breakfast/Lunch/Snack/Dinner)
- Props: `mealSlot`, `recommendedMeal?`, `loggedMeal?`, `onTap`
- Apple card style: white, `borderRadius: 16`, subtle shadow

#### [NEW] [activity_card.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/gluconav_home/widgets/activity_card.dart)
- Exercise card with icon, name, duration, glucose drop badge
- Same Apple card style

#### [NEW] [gluconav_dashboard_bloc.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/gluconav_home/bloc/gluconav_dashboard_bloc.dart)
- Events: `LoadRecommendations(userId, context)`, `UpdateContext`, `LogMealDone`, `LogActivityDone`
- States: `RecommendationsLoading`, `RecommendationsLoaded(meals, exercises, warning, coachMode)`, `RecommendationsError`

#### [NEW] [eating_sequence_sheet.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/gluconav_home/eating_sequence_sheet.dart)
- `DraggableScrollableSheet`
- Numbered steps: 🥗 Eat veggies first → 🥩 Protein → 🍚 Carbs last
- Spike comparison: `Without order: +67 mg/dL` vs `With order: +24 mg/dL`

---

### Component 4 — Profile + Diary Combined

#### [NEW] [gluconav_profile_screen.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/gluconav_profile/gluconav_profile_screen.dart)
- Top half: ONT `DiaryPage` widget embedded (today's log + calorie ring)
- Bottom half: ONT profile fields + GlucoNav diabetes fields
- Edit button → `showModalBottomSheet` with editable form

---

### Component 5 — Onboarding Extension (J5)

#### [NEW] [onboarding_gluconav_page_body.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/onboarding/presentation/widgets/onboarding_gluconav_page_body.dart)
- Diabetes Type (SegmentedButton: Type 1 / Type 2 / Prediabetes)
- HbA1c band (dropdown: <6.5 / 6.5–8 / >8)
- Cuisine (dropdown: North Indian / South Indian / Bengali / Gujarati / Pan-Indian)
- Diet (dropdown: Vegetarian / Eggetarian / Non-Vegetarian)

#### [MODIFY] [onboarding_screen.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/features/onboarding/onboarding_screen.dart)
- Add `OnboardingGlucoNavPageBody` as page 5 (before the overview/summary page)

#### [NEW] [gluconav_api_service.dart](file:///d:/Medathon/GlucoNav/frontend/OpenNutriTracker/lib/core/data/data_source/gluconav_api_service.dart)
- `onboardUser()` → `POST /api/v1/users/onboard`
- `getRecommendations()` → `GET /api/v1/recommend/{user_id}`
- `logFeedback()` → `POST /api/v1/feedback`
- `analyzeMeal()` → `POST /api/v1/analyze-meal`

---

## Updated TEAM_PLAN.md Tasks

```
J0: App rename + Apple theme (color_schemes, pubspec, main.dart)
J5: Onboarding extension + GlucoNav API service
J6: Home screen (3 sections: context banner, meals row, activity row) + Dashboard BLoC
J7: Camera sheet (3 options) + Eating sequence sheet
J8: Profile+Diary combined screen
```

---

## Verification Plan

1. **Theme**: `flutter run -d chrome` → canvas is `#F5F5F7`, cards are white, teal CTAs
2. **Navigation**: 3 tabs visible, Camera tap opens bottom sheet (not a page), Profile shows diary+profile
3. **Home sections**: Meal slot cards in horizontal row, activity cards in horizontal row, both have `+` as last card
4. **Onboarding**: Step 5 shows diabetes fields; on finish FastAPI receives onboard POST
5. **Recommendations**: AI Suggest button refreshes meal + exercise cards with spike badges
