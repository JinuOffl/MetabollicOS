import 'package:fl_chart/fl_chart.dart';
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
  // Glucose trend chart history (last 20 readings from CGM)
  final List<double> _glucoseHistory = [120, 118, 122, 125, 130, 128, 135, 140, 138];
  double _glucoseValue = 125;

  List<DietRecommendation>? _activeDiets;
  List<ExerciseRecommendation>? _activeExercises;
  RecommendResponse? _lastResp;

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

        if (_lastResp != resp) {
          _lastResp = resp;
          _activeDiets = resp.dietRecommendations.take(3).toList();
          _activeExercises = resp.exerciseRecommendations.take(3).toList();

          if (resp.currentGlucose != null) {
            _glucoseValue = resp.currentGlucose!;
            // Append to rolling history for the line chart (max 20 points)
            _glucoseHistory.add(resp.currentGlucose!);
            if (_glucoseHistory.length > 20) _glucoseHistory.removeAt(0);
          }
        }

        return Scaffold(
          backgroundColor: GlucoNavColors.background,
          appBar: _buildAppBar(context, mode, accent, loaded.streakDays, loaded.isLiveData),
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

                // ── Glucose trend chart (replaces sliders) ─────────────────
                _GlucoseChartCard(
                  glucoseHistory: _glucoseHistory,
                  currentGlucose: _glucoseValue,
                  accent: accent,
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
                  label: 'Meals Today',
                  icon: Icons.restaurant_menu,
                  color: accent,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._activeDiets!.map((m) => GestureDetector(
                            onLongPress: () {
                              final alternatives = resp.dietRecommendations
                                  .where((d) => !_activeDiets!.contains(d))
                                  .toList();
                              if (alternatives.isEmpty) return;
                              _showMealSwapModal(context, m, alternatives, accent, (selected) {
                                setState(() {
                                  final idx = _activeDiets!.indexOf(m);
                                  if (idx != -1) _activeDiets![idx] = selected;
                                });
                              });
                            },
                            child: _MealCard(meal: m, mode: mode, accent: accent),
                          )),
                      _AddMealSlotCard(accent: accent),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text('Eating order matters ↗', style: TextStyle(color: accent, fontSize: 13)),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Exercise recommendations ───────────────────────────────
                _SectionHeader(
                  label: 'Activity',
                  icon: Icons.directions_walk,
                  color: accent,
                ),
                const SizedBox(height: 12),

                // Pinned: Post Meal Walk
                _ActivityCard(
                  exerciseId: 'post_meal_walk',
                  name: 'Post Meal Walk',
                  emoji: '🚶',
                  durationMinutes: 10,
                  glucoseBenefit: 20,
                  timing: '20 min after meal',
                  reason: 'A short walk right after eating flattens your glucose spike by up to 30%.',
                  accent: accent,
                  isPinned: true,
                  onCompleted: () {
                    context.read<GlucoNavDashboardBloc>().add(const IncrementStreak());
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_doneCopy(mode)),
                      backgroundColor: accent,
                    ));
                  },
                ),
                const SizedBox(height: 10),

                // API-driven activity cards
                ..._activeExercises!.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityCard(
                    exerciseId: entry.value.exerciseId ?? 'ex_${entry.key}',
                    name: entry.value.name,
                    emoji: _exerciseEmoji(entry.value.name),
                    durationMinutes: entry.value.durationMinutes ?? 10,
                    glucoseBenefit: (entry.value.glucoseBenefitMgDl ?? 15).toDouble(),
                    timing: entry.value.timing ?? 'post_meal',
                    reason: entry.value.reason ?? 'Recommended activity for your glucose profile.',
                    accent: accent,
                    onCompleted: () {
                      context.read<GlucoNavDashboardBloc>().add(const IncrementStreak());
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(_doneCopy(mode)),
                        backgroundColor: accent,
                      ));
                    },
                  ),
                )),
                const SizedBox(height: 8),
                // K5.2 — Developer pairing ID + LIVE/DEMO indicator
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('DEVICE PAIRING ID',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: GlucoNavColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(width: 8),
                          // LIVE / DEMO data-source indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: loaded.isLiveData
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              loaded.isLiveData ? '● LIVE' : '○ DEMO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: loaded.isLiveData
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        GlucoNavApiService.userId,
                        style: TextStyle(
                            fontSize: 12,
                            color: accent.withOpacity(0.6),
                            fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, String mode, Color accent, int streak, bool isLiveData) {
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
        // LIVE / DEMO chip — instantly visible data-source indicator for demos
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isLiveData
                ? Colors.green.withOpacity(0.12)
                : Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLiveData
                  ? Colors.green.withOpacity(0.4)
                  : Colors.orange.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Text(
            isLiveData ? '● LIVE' : '○ DEMO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isLiveData ? Colors.green[700] : Colors.orange[700],
              letterSpacing: 0.5,
            ),
          ),
        ),
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

/// Live glucose trend line chart — replaces the old sleep/glucose sliders.
/// Shows the last 20 CGM readings, auto-colors red above 180 mg/dL.
class _GlucoseChartCard extends StatelessWidget {
  final List<double> glucoseHistory;
  final double currentGlucose;
  final Color accent;

  const _GlucoseChartCard({
    required this.glucoseHistory,
    required this.currentGlucose,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isHigh = currentGlucose > 180;
    final isLow  = currentGlucose < 70;
    final chartColor = isHigh
        ? GlucoNavColors.spikeHigh
        : isLow
            ? const Color(0xFF3B82F6)
            : accent;

    final statusText = isHigh
        ? '⚠️ High glucose'
        : isLow
            ? '⚠️ Below target'
            : '✓ In range';
    final statusColor = isHigh
        ? GlucoNavColors.spikeHigh
        : isLow
            ? const Color(0xFF3B82F6)
            : GlucoNavColors.spikeLow;

    // Build fl_chart spots
    final spots = glucoseHistory.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: GlucoNavColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chartColor.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Glucose Trend',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: GlucoNavColors.textSecondary,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${currentGlucose.round()}',
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: chartColor,
                            letterSpacing: -1),
                      ),
                      const SizedBox(width: 4),
                      const Text('mg/dL',
                          style: TextStyle(
                              fontSize: 13,
                              color: GlucoNavColors.textSecondary)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showCGMConnectDialog(context),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: GlucoNavColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings_input_antenna, size: 16, color: GlucoNavColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Line chart
          SizedBox(
            height: 80,
            child: spots.length < 2
                ? Center(
                    child: Text('Waiting for CGM data...',
                        style: TextStyle(
                            color: GlucoNavColors.textSecondary,
                            fontSize: 12)))
                : LineChart(
                    LineChartData(
                      minY: 50,
                      maxY: 280,
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 60,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: GlucoNavColors.textSecondary.withOpacity(0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 70,
                            getTitlesWidget: (v, _) => Text(
                              v.round().toString(),
                              style: const TextStyle(
                                  fontSize: 9, color: GlucoNavColors.textSecondary),
                            ),
                          ),
                        ),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: chartColor,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, _) =>
                                spot == spots.last,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                                    radius: 4,
                                    color: chartColor,
                                    strokeColor: Colors.white,
                                    strokeWidth: 1.5),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                chartColor.withOpacity(0.18),
                                chartColor.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                        // 180 mg/dL danger threshold line
                        LineChartBarData(
                          spots: [FlSpot(0, 180), FlSpot((spots.length - 1).toDouble(), 180)],
                          color: GlucoNavColors.spikeHigh.withOpacity(0.35),
                          barWidth: 1,
                          dashArray: [6, 4],
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          const Text('↑ 180 mg/dL threshold  •  Real-time CGM data',
              style: TextStyle(
                  fontSize: 9,
                  color: GlucoNavColors.textSecondary)),
        ],
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
    final showSpikeColor = mode != 'supportive' || isGood;
    final hasImage = meal.imageUrl != null && meal.imageUrl!.isNotEmpty;

    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: GlucoNavColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full-width image banner ──────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: hasImage
                ? Image.network(
                    meal.imageUrl!,
                    width: 155,
                    height: 90,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 155, height: 90,
                        color: showSpikeColor ? spikeColor.withOpacity(0.08) : GlucoNavColors.surfaceVariant,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: 155, height: 90,
                      color: showSpikeColor ? spikeColor.withOpacity(0.08) : GlucoNavColors.surfaceVariant,
                      child: Icon(Icons.restaurant, color: accent.withOpacity(0.4), size: 32),
                    ),
                  )
                : Container(
                    width: 155, height: 90,
                    color: showSpikeColor ? spikeColor.withOpacity(0.08) : GlucoNavColors.surfaceVariant,
                    child: Icon(Icons.restaurant, color: showSpikeColor ? spikeColor.withOpacity(0.4) : accent.withOpacity(0.4), size: 32),
                  ),
          ),
          // ── Text info ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: GlucoNavColors.textPrimary)),
                if (meal.cuisine != null)
                  Text(meal.cuisine!, style: const TextStyle(fontSize: 10, color: GlucoNavColors.textSecondary)),
                const SizedBox(height: 8),
                if (delta != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: showSpikeColor ? spikeColor.withOpacity(0.12) : GlucoNavColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${delta.round()} mg/dL',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: showSpikeColor ? spikeColor : GlucoNavColors.textSecondary),
                    ),
                  ),
                if (meal.insulinDose != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '💉 ${meal.insulinDose}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF6366F1)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _AddMealSlotCard extends StatelessWidget {
  final Color accent;
  const _AddMealSlotCard({required this.accent});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLogModal(context, 'Meal', accent),
      child: Container(
        width: 140,
        height: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add, color: accent),
            ),
            const SizedBox(height: 8),
            Text('Log a Meal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: accent)),
          ],
        ),
      ),
    );
  }
}

String _exerciseEmoji(String name) {
  final n = name.toLowerCase();
  if (n.contains('walk') || n.contains('stroll')) return '🚶';
  if (n.contains('run') || n.contains('jog')) return '🏃';
  if (n.contains('yoga') || n.contains('stretch')) return '🧘';
  if (n.contains('squat') || n.contains('strength')) return '💪';
  if (n.contains('cycle') || n.contains('bike')) return '🚴';
  if (n.contains('swim')) return '🏊';
  if (n.contains('dance')) return '💃';
  return '🏋️';
}

// ── Premium Activity Card with timer + completion tracking ────────────────────

class _ActivityCard extends StatefulWidget {
  final String exerciseId;
  final String name;
  final String emoji;
  final int durationMinutes;
  final double glucoseBenefit;
  final String timing;
  final String reason;
  final Color accent;
  final bool isPinned;
  final VoidCallback onCompleted;

  const _ActivityCard({
    required this.exerciseId,
    required this.name,
    required this.emoji,
    required this.durationMinutes,
    required this.glucoseBenefit,
    required this.timing,
    required this.reason,
    required this.accent,
    required this.onCompleted,
    this.isPinned = false,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> with SingleTickerProviderStateMixin {
  bool _completed = false;
  bool _inProgress = false;
  int _secondsRemaining = 0;
  late AnimationController _checkAnim;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationMinutes * 60;
    _checkAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_inProgress || _completed) return;
    setState(() => _inProgress = true);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        setState(() {
          _inProgress = false;
          _secondsRemaining = 0;
        });
        return false;
      }
      return _inProgress;
    });
  }

  void _markComplete() {
    setState(() {
      _completed = true;
      _inProgress = false;
    });
    _checkAnim.forward();
    widget.onCompleted();
  }

  String get _timerDisplay {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = widget.durationMinutes * 60;
    if (total == 0) return 1.0;
    return 1.0 - (_secondsRemaining / total);
  }

  @override
  Widget build(BuildContext context) {
    final completedColor = const Color(0xFF10B981);
    final cardBorder = _completed
        ? completedColor
        : _inProgress
            ? widget.accent
            : widget.accent.withOpacity(0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _completed
            ? completedColor.withOpacity(0.06)
            : GlucoNavColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: _inProgress ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: cardBorder.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _completed
                                    ? completedColor
                                    : GlucoNavColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.isPinned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Recommended',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: widget.accent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.durationMinutes} min  •  ${widget.timing.replaceAll('_', ' ')}',
                        style: const TextStyle(fontSize: 11, color: GlucoNavColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Glucose benefit badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GlucoNavColors.spikeLow.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '−${widget.glucoseBenefit.round()} mg/dL',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: GlucoNavColors.spikeLow,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Reason text
            Text(
              widget.reason,
              style: const TextStyle(fontSize: 11, color: GlucoNavColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 14),

            // Timer + progress bar (only when in progress)
            if (_inProgress) ...[
              Row(
                children: [
                  Text(
                    _timerDisplay,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.accent,
                      fontFeatures: const [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('remaining', style: TextStyle(fontSize: 11, color: GlucoNavColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  color: widget.accent,
                  backgroundColor: widget.accent.withOpacity(0.12),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action buttons
            if (!_completed)
              Row(
                children: [
                  if (!_inProgress)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _startTimer,
                        icon: Icon(Icons.play_arrow, color: widget.accent, size: 16),
                        label: Text('Start', style: TextStyle(color: widget.accent, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: widget.accent.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _inProgress = false;
                          _secondsRemaining = widget.durationMinutes * 60;
                        }),
                        icon: const Icon(Icons.stop, color: GlucoNavColors.textSecondary, size: 16),
                        label: const Text('Stop', style: TextStyle(color: GlucoNavColors.textSecondary, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: GlucoNavColors.textSecondary, width: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _markComplete,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                      label: const Text('Mark Complete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: completedColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              )
            else
              // Completed state
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: completedColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Completed! 🔥 Glucose spike flattened',
                    style: TextStyle(color: completedColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}


class _AddActivitySlotCard extends StatelessWidget {
  final Color accent;
  const _AddActivitySlotCard({required this.accent});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLogModal(context, 'Activity', accent),
      child: Container(
        width: 155,
        height: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add, color: accent),
            ),
            const SizedBox(height: 8),
            Text('Log Activity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: accent)),
          ],
        ),
      ),
    );
  }
}

void _showMealSwapModal(BuildContext context, DietRecommendation current, List<DietRecommendation> alternatives, Color accent, Function(DietRecommendation) onSwap) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Container(
      height: MediaQuery.of(ctx).size.height * 0.6,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Swap ${current.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Pick a delicious alternative that maintains your glucose stability.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: alternatives.length,
              itemBuilder: (ctx, i) {
                final m = alternatives[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restaurant, color: GlucoNavColors.primary),
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text("${m.cuisine ?? 'Global'} • GI: ${(m.gi ?? 0.0).round()} • Spike: +${(m.predictedGlucoseDelta ?? 0.0).round()}"),
                  trailing: IconButton(
                    icon: Icon(Icons.swap_horiz, color: accent),
                    onPressed: () {
                      onSwap(m);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

void _showExerciseSwapModal(BuildContext context, ExerciseRecommendation current, List<ExerciseRecommendation> alternatives, Color accent, Function(ExerciseRecommendation) onSwap) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Container(
      height: MediaQuery.of(ctx).size.height * 0.6,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Swap ${current.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Find an alternative activity that fits your mood.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: alternatives.length,
              itemBuilder: (ctx, i) {
                final ex = alternatives[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_walk, color: GlucoNavColors.primary),
                  title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text("${ex.durationMinutes ?? 10}m • Benefit: -${ex.glucoseBenefitMgDl?.round() ?? 10} mg/dL"),
                  trailing: IconButton(
                    icon: Icon(Icons.swap_horiz, color: accent),
                    onPressed: () {
                      onSwap(ex);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

void _showLogModal(BuildContext context, String type, Color accent) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type == 'Meal' ? Icons.restaurant : Icons.directions_walk, color: accent),
              const SizedBox(width: 8),
              Text('Log a $type', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: type == 'Meal' ? 'e.g. 2 Idlis and Coffee' : 'e.g. 15 min Brisk Walk',
              filled: true,
              fillColor: GlucoNavColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  // Fire and forget feedback API call
                  GlucoNavApiService().logFeedback(
                    itemId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                    itemType: type.toLowerCase(),
                    interactionType: 'logged',
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$type Logged Successfully!'), backgroundColor: accent),
                  );
                }
              },
              child: const Text('Add to Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
}

/// Shows a dialog to pair the app with the CGM Simulator device.
/// User enters: IP address, Port (default 8000), User ID
/// On save, updates GlucoNavApiService base URL and userId in SharedPreferences.
void _showCGMConnectDialog(BuildContext context) {
  final ipCtrl = TextEditingController(text: '10.240.206.169');
  final portCtrl = TextEditingController(text: '8000');
  final uIdCtrl = TextEditingController(text: GlucoNavApiService.userId);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_input_antenna, color: GlucoNavColors.primary),
          SizedBox(width: 8),
          Text('Connect CGM Device', style: TextStyle(fontSize: 17)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Get these values from the CGM Simulator page (http://10.240.206.169:5000).',
            style: TextStyle(fontSize: 12, color: GlucoNavColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ipCtrl,
            decoration: const InputDecoration(
              labelText: 'Server IP',
              hintText: 'e.g. 192.168.1.5 or localhost',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: portCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '8000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: uIdCtrl,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Paste User ID from simulator',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: GlucoNavColors.primary),
          onPressed: () async {
            final ip = ipCtrl.text.trim();
            final port = portCtrl.text.trim().isEmpty ? '8000' : portCtrl.text.trim();
            final uid = uIdCtrl.text.trim();
            if (ip.isEmpty || uid.isEmpty) return;

            // Update the static base URL (runtime only — no hot restart needed)
            await GlucoNavApiService.setServerConfig(ip: ip, port: port);
            await GlucoNavApiService.setUserId(uid);

            Navigator.pop(ctx);
            if (ctx.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Connected to $ip:$port as $uid'),
                  backgroundColor: GlucoNavColors.primary,
                ),
              );
              // Trigger immediate dashboard reload
              context.read<GlucoNavDashboardBloc>().add(const LoadDashboard());
            }
          },
          child: const Text('Connect', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
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
