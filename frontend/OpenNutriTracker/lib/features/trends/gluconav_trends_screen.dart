import 'package:flutter/material.dart';

import '../../core/gluconav_colors.dart';

/// L9.2 — Trends screen: 71% Time-in-Range donut + 12-day streak badge.
///
/// Data is hardcoded for the hackathon demo (demo_user_experienced profile).
/// In production this pulls from GET /api/v1/glucose-readings/{user_id}.
class GlucoNavTrendsScreen extends StatelessWidget {
  const GlucoNavTrendsScreen({super.key});

  // ── Demo data ──────────────────────────────────────────────────────────────
  static const double _tirPercent = 71.0;   // Time-in-Range 70–140 mg/dL
  static const int _streakDays = 12;
  static const double _avgGlucose = 118.0;  // mg/dL
  static const double _avgSpike = 22.0;     // avg post-meal delta mg/dL
  static const int _activitiesCompleted = 9;

  // Weekly glucose readings (Sun → Sat) in mg/dL — for the sparkline
  static const _weeklyReadings = [135.0, 128.0, 142.0, 119.0, 124.0, 116.0, 111.0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlucoNavColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Trends',
          style: TextStyle(
              color: GlucoNavColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Row 1: TiR donut + streak badge ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TirDonutCard(tirPercent: _tirPercent)),
              const SizedBox(width: 12),
              const Expanded(child: _StreakCard(streakDays: _streakDays)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Stats row ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Avg Glucose',
                  value: '${_avgGlucose.round()}',
                  unit: 'mg/dL',
                  icon: Icons.water_drop_outlined,
                  color: GlucoNavColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Avg Post-meal Spike',
                  value: '+${_avgSpike.round()}',
                  unit: 'mg/dL',
                  icon: Icons.trending_up,
                  color: GlucoNavColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Activities Done',
                  value: '$_activitiesCompleted',
                  unit: 'this week',
                  icon: Icons.directions_walk,
                  color: GlucoNavColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Weekly sparkline ───────────────────────────────────────────────
          _WeeklyGlucoseCard(readings: _weeklyReadings),
          const SizedBox(height: 20),

          // ── Personalization proof (demo) ───────────────────────────────────
          _PersonalizationCard(),
        ],
      ),
    );
  }
}

// ── Time-in-Range donut card ──────────────────────────────────────────────────

class _TirDonutCard extends StatelessWidget {
  final double tirPercent;
  const _TirDonutCard({required this.tirPercent});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: GlucoNavColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Time in Range',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GlucoNavColors.textSecondary)),
            const SizedBox(height: 12),
            _DonutPainterWidget(percent: tirPercent),
            const SizedBox(height: 8),
            const Text(
              '70–140 mg/dL',
              style: TextStyle(
                  fontSize: 10, color: GlucoNavColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainterWidget extends StatelessWidget {
  final double percent;
  const _DonutPainterWidget({required this.percent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(100, 100),
            painter: _DonutPainter(percent: percent),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${percent.round()}%',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: GlucoNavColors.primary),
              ),
              const Text('TiR',
                  style: TextStyle(
                      fontSize: 10,
                      color: GlucoNavColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;
  _DonutPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - strokeWidth / 2);

    // Background arc
    canvas.drawArc(
      rect, -1.5708, 6.2832, false,
      Paint()
        ..color = GlucoNavColors.primary.withOpacity(0.12)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Filled arc
    final sweepAngle = 6.2832 * (percent / 100);
    canvas.drawArc(
      rect, -1.5708, sweepAngle, false,
      Paint()
        ..color = GlucoNavColors.primary
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.percent != percent;
}

// ── Streak badge card ─────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final int streakDays;
  const _StreakCard({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: GlucoNavColors.primary,
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔥 Streak',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
            const SizedBox(height: 12),
            Text(
              '$streakDays',
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1),
            ),
            const Text('days',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            const Text(
              'Keep logging to maintain your streak!',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: GlucoNavColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(unit,
                style: const TextStyle(
                    fontSize: 9, color: GlucoNavColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: GlucoNavColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Weekly glucose sparkline ──────────────────────────────────────────────────

class _WeeklyGlucoseCard extends StatelessWidget {
  final List<double> readings;
  const _WeeklyGlucoseCard({required this.readings});

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final max = readings.reduce((a, b) => a > b ? a : b);
    final min = readings.reduce((a, b) => a < b ? a : b);
    final range = (max - min).clamp(10.0, double.infinity);

    return Card(
      color: GlucoNavColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Glucose',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: GlucoNavColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Fasting readings (mg/dL)',
                style: TextStyle(
                    fontSize: 11, color: GlucoNavColors.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: readings.asMap().entries.map((e) {
                  final pct = ((e.value - min) / range).clamp(0.1, 1.0);
                  final isTarget = e.value <= 140 && e.value >= 70;
                  return _BarColumn(
                    label: _days[e.key],
                    value: e.value.round(),
                    heightFraction: pct,
                    color: isTarget
                        ? GlucoNavColors.primary
                        : GlucoNavColors.spikeHigh,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // Target range indicator
            Row(
              children: [
                Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: GlucoNavColors.primary,
                        shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('In range (70–140)',
                    style: TextStyle(
                        fontSize: 10, color: GlucoNavColors.textSecondary)),
                const SizedBox(width: 12),
                Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: GlucoNavColors.spikeHigh,
                        shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Above target',
                    style: TextStyle(
                        fontSize: 10, color: GlucoNavColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final String label;
  final int value;
  final double heightFraction;
  final Color color;
  const _BarColumn({
    required this.label,
    required this.value,
    required this.heightFraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Container(
          width: 28,
          height: 60 * heightFraction,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: GlucoNavColors.textSecondary)),
      ],
    );
  }
}

// ── Personalization proof card (demo talking point) ───────────────────────────

class _PersonalizationCard extends StatelessWidget {
  _PersonalizationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: GlucoNavColors.surfaceVariant,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side:
              BorderSide(color: GlucoNavColors.primary.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: GlucoNavColors.primary, size: 18),
                const SizedBox(width: 6),
                const Text('Personalization Impact',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: GlucoNavColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            _ComparisonRow(
              label: 'New user (Day 1)',
              spike: '+54 mg/dL',
              color: GlucoNavColors.spikeHigh,
            ),
            const SizedBox(height: 8),
            _ComparisonRow(
              label: 'You (Day 14)',
              spike: '+22 mg/dL',
              color: GlucoNavColors.spikeLow,
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: GlucoNavColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '📉 59% better spike control after 14 days of personalisation',
                style: TextStyle(
                    fontSize: 12,
                    color: GlucoNavColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String spike;
  final Color color;
  const _ComparisonRow(
      {required this.label, required this.spike, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: GlucoNavColors.textSecondary)),
        ),
        Text(spike,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}
