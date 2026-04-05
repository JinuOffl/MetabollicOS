import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/gluconav_colors.dart';
import 'features/activity/activity_snack_screen.dart'; // To be removed or used later?
import 'features/gluconav_dashboard/gluconav_dashboard_bloc.dart';
import 'features/gluconav_dashboard/gluconav_dashboard_screen.dart';
import 'features/sequence/camera_screen.dart';
import 'features/trends/gluconav_trends_screen.dart';
import 'features/onboarding/gluco_onboarding_screen.dart';
import 'services/gluconav_api_service.dart';

/// Phase 6.5 — I1.5
/// Run both backend and frontend:
///
///   Terminal 1 (backend):
///     cd backend && python run.py
///     → FastAPI at http://localhost:8000
///
///   Terminal 2 (frontend):
///     cd frontend/OpenNutriTracker
///     flutter pub get
///     flutter run -d chrome
///
/// The app auto-detects backend availability.
/// If backend is unreachable → falls back to rich mock data.
/// Default user: demo_user_experienced (seeded by scripts/seed_demo.py).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted user_id from SharedPreferences
  bool hasUser = await GlucoNavApiService.initUserId();

  runApp(GlucoNavApp(hasUser: hasUser));
}

class GlucoNavApp extends StatelessWidget {
  final bool hasUser;
  const GlucoNavApp({super.key, required this.hasUser});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => GlucoNavDashboardBloc(GlucoNavApiService())
            ..add(const LoadDashboard()),
        ),
      ],
      child: MaterialApp(
        title: 'GlucoNav',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: GlucoNavColors.primary),
          scaffoldBackgroundColor: GlucoNavColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          cardTheme: CardThemeData(
            color: GlucoNavColors.card,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlucoNavColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: GlucoNavColors.primary,
            thumbColor: GlucoNavColors.primary,
            inactiveTrackColor: GlucoNavColors.primary.withOpacity(0.2),
          ),
        ),
        home: hasUser ? const GlucoNavShell() : const GlucoOnboardingScreen(),
      ),
    );
  }
}

// ── 4-tab shell ───────────────────────────────────────────────────────────────

class GlucoNavShell extends StatefulWidget {
  const GlucoNavShell({super.key});

  @override
  State<GlucoNavShell> createState() => _GlucoNavShellState();
}

class _GlucoNavShellState extends State<GlucoNavShell> {
  int _index = 1; // default: Home

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          SizedBox.shrink(), // Index 0 is Camera overlay, not loaded in stack
          GlucoNavDashboardScreen(), // Index 1: Home
          GlucoNavTrendsScreen(),    // Index 2: Profile
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: GlucoNavColors.primary.withOpacity(0.15),
        elevation: 4,
        onDestinationSelected: (i) {
          if (i == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          } else {
            setState(() => _index = i);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt, color: GlucoNavColors.primary),
            label: 'Camera',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: GlucoNavColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: GlucoNavColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}


