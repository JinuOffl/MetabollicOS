import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/gluconav_colors.dart';
import '../../models/recommendation_response.dart';
import '../../services/gluconav_api_service.dart';
import '../sequence/camera_screen.dart';
import 'gluconav_dashboard_bloc.dart';

/// GlucoNav AI Suggest dashboard tab.
///
/// L6.5 — "Scan My Plate" button navigates to CameraScreen.
/// L8   — coach_mode field from response drives UI tone:
///          active      → teal badges, streak shown, performance language
///          balanced    → blue accent, neutral copy, streak hidden
///          supportive  → purple accent, soft copy, no red warnings, emojis
class GlucoNavDashboardScreen extends StatelessWidget {
  const GlucoNavDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          GlucoNavDashboardBloc(GlucoNavApiService())..add(const LoadDashboard()),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  double _sleepScore = 0.7;
  double _glucoseValue = 125;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GlucoNavDashboardBloc, GlucoNavDashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is DashboardError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: GlucoNavColors.spikeHigh),
                  const SizedBox(height: 12),
                  Text(state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: GlucoNavColors.textSecondary)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<GlucoNavDashboardBloc>().add(const LoadDashboard()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final loaded = state as DashboardLoaded;
        final resp = loaded.response;
        final mode = resp.coachMode;
        final accent = GlucoNavColors.forCoachMode(mode);

        return Scaffold(
          backgroundColor: GlucoNavColors.background,
          appBar: _buildAppBar(context, mode, accent, loaded.streakDays),
          body: RefreshIndicator(
            color: accent,
            onRefresh: () async =>
                context.read<GlucoNavDashboardBloc>().add(const LoadDashboard()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // ── Context warning banner ─────────────────────────────────
                if (resp.contextWarning != null && mode != 'supportive')
                  _WarningBanner(text: resp.contextWarning!),

                // ── Context inputs ─────────────────────────────────────────
                _ContextInputCard(
                  sleepScore: _sleepScore,
                  glucoseValue: _glucoseValue,
                  accent: accent,
                  onSleepChanged: (v) {
                    setState(() => _sleepScore = v);
                    context.read<GlucoNavDashboardBloc>().add(
                        UpdateContext(sleepScore: v, currentGlucose: _glucoseValue));
                  },
                  onGlucoseChanged: (v) {
                    setState(() => _glucoseValue = v);
                  },
                ),

                const SizedBox(height: 16),

                // ── Scan My Plate CTA (L6.5) ───────────────────────────────
                _ScanMyPlateButton(accent: accent),

                const SizedBox(height: 20),

                // ── Spike risk chip ────────────────────────────────────────
                _SpikeRiskRow(spikeRisk: resp.spikeRisk, mode: mode),

                const SizedBox(height: 20),

                // ── Meal recommendations ───────────────────────────────────
                _SectionHeader(
                  label: _mealSectionLabel(mode),
                  icon: Icons.restaurant_menu,
                  color: accent,
                ),
                const SizedBox(height: 8),
                ...resp.dietRecommendations
                    .map((m) => _MealCard(meal: m, mode: mode, accent: accent)),

                const SizedBox(height: 24),

                // ── Exercise recommendations ───────────────────────────────
                _SectionHeader(
                  label: _exerciseSectionLabel(mode),
                  icon: Icons.directions_walk,
                  color: accent,
                ),
                const SizedBox(height: 8),
                ...resp.exerciseRecommendations.map((e) => _ExerciseCard(
                      exercise: e,
                      spikeRisk: resp.spikeRisk,
                      mode: mode,
                      accent: accent,
                      onDone: () {
                        context
                            .read<GlucoNavDashboardBloc>()
                            .add(const IncrementStreak());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_doneCopy(mode)),
                            backgroundColor: accent,
                          ),
                        );
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, String mode, Color accent, int streak) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'GlucoNav',
        style: TextStyle(
            fontWeight: FontWeight.bold,
            color: GlucoNavColors.primary,
            fontSize: 20),
      ),
      actions: [
        // L8.5 — animated coach-mode chip
        _CoachModeChip(mode: mode, accent: accent),
        const SizedBox(width: 8),
        // Streak badge (hidden in balanced + supportive mode — L8.3)
        if (mode != 'balanced' && mode != 'supportive')
          _StreakBadge(days: streak),
        const SizedBox(width: 12),
      ],
    );
  }

  String _mealSectionLabel(String mode) {
    if (mode == 'supportive') return 'Meals you might enjoy today 💚';
    if (mode == 'balanced') return 'Recommended meals';
    return 'Top meal picks for you 🎯';
  }

  String _exerciseSectionLabel(String mode) {
    if (mode == 'supportive') return 'Gentle movement ideas 🌿';
    if (mode == 'balanced') return 'Post-meal activity';
    return 'Activity snacks to crush the spike 💪';
  }

  String _doneCopy(String mode) {
    if (mode == 'supportive') return "You're doing great 💚 Keep it up!";
    if (mode == 'balanced') return 'Activity logged. Well done!';
    return '🔥 Streak extended! Glucose spike flattened.';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GlucoNavColors.spikeHigh.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlucoNavColors.spikeHigh.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: GlucoNavColors.spikeHigh, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: GlucoNavColors.textPrimary))),
        ],
      ),
    );
  }
}

class _ContextInputCard extends StatelessWidget {
  final double sleepScore;
  final double glucoseValue;
  final Color accent;
  final ValueChanged<double> onSleepChanged;
  final ValueChanged<double> onGlucoseChanged;

  const _ContextInputCard({
    required this.sleepScore,
    required this.glucoseValue,
    required this.accent,
    required this.onSleepChanged,
    required this.onGlucoseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: GlucoNavColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's context",
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: accent,
                    fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.bedtime_outlined, size: 16,
                    color: GlucoNavColors.textSecondary),
                const SizedBox(width: 6),
                const Text('Sleep quality',
                    style: TextStyle(
                        fontSize: 12, color: GlucoNavColors.textSecondary)),
                const Spacer(),
                Text('${(sleepScore * 10).round()}/10',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: accent)),
              ],
            ),
            Slider(
              value: sleepScore,
              min: 0,
              max: 1,
              divisions: 10,
              activeColor: accent,
              inactiveColor: accent.withOpacity(0.2),
              onChanged: onSleepChanged,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.water_drop_outlined, size: 16,
                    color: GlucoNavColors.textSecondary),
                const SizedBox(width: 6),
                const Text('Current glucose',
                    style: TextStyle(
                        fontSize: 12, color: GlucoNavColors.textSecondary)),
                const Spacer(),
                Text('${glucoseValue.round()} mg/dL',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: accent)),
              ],
            ),
            Slider(
              value: glucoseValue,
              min: 70,
              max: 250,
              divisions: 36,
              activeColor: accent,
              inactiveColor: accent.withOpacity(0.2),
              onChanged: onGlucoseChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// L6.5 — "Scan My Plate" entry point wired to CameraScreen.
class _ScanMyPlateButton extends StatelessWidget {
  final Color accent;
  const _ScanMyPlateButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withOpacity(0.8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: accent.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Scan My Plate',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3),
            ),
            SizedBox(width: 8),
            Text('🍽️', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _SpikeRiskRow extends StatelessWidget {
  final String spikeRisk;
  final String mode;
  const _SpikeRiskRow({required this.spikeRisk, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == 'supportive' && spikeRisk == 'high') return const SizedBox.shrink();
    final color = GlucoNavColors.forSpikeRisk(spikeRisk);
    final label = spikeRisk == 'high'
        ? '🔴 High spike risk — eat fibre first'
        : spikeRisk == 'medium'
            ? '🟡 Medium spike risk'
            : '🟢 Low spike risk today';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: GlucoNavColors.textPrimary)),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final DietRecommendation meal;
  final String mode;
  final Color accent;
  const _MealCard({required this.meal, required this.mode, required this.accent});

  @override
  Widget build(BuildContext context) {
    final delta = meal.predictedGlucoseDelta;
    final isGood = meal.isLowSpike;
    final spikeColor = isGood ? GlucoNavColors.spikeLow : GlucoNavColors.spikeHigh;
    final showSpikeColor = mode != 'supportive' || isGood; // L8 — hide red in supportive

    return Card(
      color: GlucoNavColors.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: showSpikeColor
                    ? spikeColor.withOpacity(0.12)
                    : GlucoNavColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: delta != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('+${delta.round()}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: showSpikeColor ? spikeColor : GlucoNavColors.textSecondary)),
                          Text('mg/dL',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: showSpikeColor ? spikeColor : GlucoNavColors.textSecondary)),
                        ],
                      )
                    : Icon(Icons.restaurant, color: accent, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: GlucoNavColors.textPrimary)),
                  if (meal.cuisine != null)
                    Text(meal.cuisine!,
                        style: const TextStyle(
                            fontSize: 11, color: GlucoNavColors.textSecondary)),
                  if (meal.reason != null) ...[
                    const SizedBox(height: 4),
                    Text(meal.reason!,
                        style: const TextStyle(
                            fontSize: 11, color: GlucoNavColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseRecommendation exercise;
  final String spikeRisk;
  final String mode;
  final Color accent;
  final VoidCallback onDone;
  const _ExerciseCard({
    required this.exercise,
    required this.spikeRisk,
    required this.mode,
    required this.accent,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final urgencyLabel = _urgencyLabel(spikeRisk, mode);
    return Card(
      color: GlucoNavColors.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accent.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${exercise.durationMinutes ?? "?"} min',
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(exercise.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: GlucoNavColors.textPrimary)),
                ),
                if (exercise.glucoseBenefitMgDl != null)
                  Text('−${exercise.glucoseBenefitMgDl!.round()} mg/dL',
                      style: const TextStyle(
                          color: GlucoNavColors.spikeLow,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
              ],
            ),
            if (exercise.reason != null) ...[
              const SizedBox(height: 6),
              Text(exercise.reason!,
                  style: const TextStyle(fontSize: 11, color: GlucoNavColors.textSecondary)),
            ],
            if (urgencyLabel != null) ...[
              const SizedBox(height: 6),
              Text(urgencyLabel,
                  style: const TextStyle(
                      fontSize: 11,
                      color: GlucoNavColors.spikeHigh,
                      fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(_doneBtnLabel(mode)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _urgencyLabel(String risk, String mode) {
    if (mode == 'supportive') return null;
    if (risk == 'high') return '⚡ High spike risk — start moving!';
    if (risk == 'medium') return 'Moderate risk — a walk will help';
    return null;
  }

  String _doneBtnLabel(String mode) {
    if (mode == 'supportive') return 'Done 💚';
    if (mode == 'balanced') return 'Mark complete';
    return 'Done! 🔥';
  }
}

class _CoachModeChip extends StatelessWidget {
  final String mode;
  final Color accent;
  const _CoachModeChip({required this.mode, required this.accent});

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      'supportive' => '💚 Supportive',
      'balanced'   => '⚖️ Balanced',
      _            => '🎯 Active',
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int days;
  const _StreakBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: GlucoNavColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text('$days days',
              style: const TextStyle(
                  fontSize: 11,
                  color: GlucoNavColors.primary,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
