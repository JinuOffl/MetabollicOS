import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/gluconav_colors.dart';
import 'features/activity/activity_snack_screen.dart';
import 'features/gluconav_dashboard/gluconav_dashboard_bloc.dart';
import 'features/gluconav_dashboard/gluconav_dashboard_screen.dart';
import 'features/trends/gluconav_trends_screen.dart';
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
  // I1.1 — must call before runApp() when using async platform APIs
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted user_id from SharedPreferences (defaults to demo_user_experienced)
  await GlucoNavApiService.initUserId();

  runApp(const GlucoNavApp());
}

class GlucoNavApp extends StatelessWidget {
  const GlucoNavApp({super.key});

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
        home: const GlucoNavShell(),
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
  int _index = 2; // default: AI Suggest

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _PlaceholderScreen(label: 'Home',  icon: Icons.home_outlined),
          _DiaryScreen(),
          GlucoNavDashboardScreen(),
          GlucoNavTrendsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: GlucoNavColors.primary.withOpacity(0.15),
        elevation: 4,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: GlucoNavColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book, color: GlucoNavColors.primary),
            label: 'Diary',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon:
                Icon(Icons.auto_awesome, color: GlucoNavColors.primary),
            label: 'AI Suggest',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon:
                Icon(Icons.trending_up, color: GlucoNavColors.primary),
            label: 'Trends',
          ),
        ],
      ),
    );
  }
}

// ── Diary tab — demo shortcuts ────────────────────────────────────────────────

class _DiaryScreen extends StatelessWidget {
  const _DiaryScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary',
            style: TextStyle(
                color: GlucoNavColors.primary, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.book_outlined,
                  size: 64, color: GlucoNavColors.primary),
              const SizedBox(height: 16),
              const Text('Demo Shortcuts',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: GlucoNavColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Quick-access buttons for hackathon demo',
                  style: TextStyle(
                      fontSize: 12, color: GlucoNavColors.textSecondary)),
              const SizedBox(height: 32),

              // I1.2 — Activity Snack demo (instant card)
              _DemoButton(
                icon: Icons.directions_walk,
                label: 'Activity Snack — high spike risk',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActivitySnackScreen(
                      exerciseName: 'Brisk Walk',
                      durationMinutes: 10,
                      glucoseBenefitMgDl: 20,
                      exerciseId: 'ex_001',
                      spikeRisk: 'high',
                      timerMinutes: 0, // instant
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // I1.3 — Switch to demo_user_new for personalization delta
              _DemoButton(
                icon: Icons.person_outlined,
                label: 'Switch → demo_user_new (generic recs)',
                color: GlucoNavColors.balancedAccent,
                onTap: () {
                  GlucoNavApiService.userId = 'demo_user_new';
                  context.findAncestorStateOfType<_GlucoNavShellState>()
                      ?.setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to demo_user_new — go to AI Suggest tab'),
                      backgroundColor: GlucoNavColors.balancedAccent,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              _DemoButton(
                icon: Icons.person,
                label: 'Switch → demo_user_experienced (personalised)',
                onTap: () {
                  GlucoNavApiService.userId = 'demo_user_experienced';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switched to demo_user_experienced — go to AI Suggest tab'),
                      backgroundColor: GlucoNavColors.primary,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DemoButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = GlucoNavColors.primary,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 18),
          label: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}

// ── Placeholder ───────────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(label,
              style: const TextStyle(
                  color: GlucoNavColors.primary, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: GlucoNavColors.primary),
              const SizedBox(height: 12),
              Text(label,
                  style: const TextStyle(
                      fontSize: 18, color: GlucoNavColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('ONT base feature',
                  style: TextStyle(
                      fontSize: 12, color: GlucoNavColors.textSecondary)),
            ],
          ),
        ),
      );
}
