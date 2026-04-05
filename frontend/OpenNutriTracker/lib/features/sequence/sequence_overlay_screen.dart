import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/gluconav_colors.dart';
import '../../models/sequence_result.dart';
import '../activity/activity_snack_screen.dart';

/// L6.2 — Displays meal photo with numbered food-item badges.
/// L6.3 — Shows a numbered step list below (food + category + reason).
/// L6.4 — Spike comparison cards + "Start Eating!" CTA.
class SequenceOverlayScreen extends StatelessWidget {
  final Uint8List imageBytes;
  final SequenceResult result;

  const SequenceOverlayScreen({
    super.key,
    required this.imageBytes,
    required this.result,
  });

  // Approximate overlay positions for up to 5 items (left/top as fraction).
  // Design decision #3: approximate regions, NOT pixel-precise bounding boxes.
  static const _overlayPositions = [
    Offset(0.12, 0.15), // step 1 — top-left
    Offset(0.55, 0.50), // step 2 — centre-right
    Offset(0.20, 0.65), // step 3 — bottom-left
    Offset(0.70, 0.15), // step 4 — top-right
    Offset(0.45, 0.75), // step 5 — bottom-centre
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlucoNavColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Eating Sequence',
          style: TextStyle(
              color: GlucoNavColors.primary, fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(color: GlucoNavColors.primary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── L6.2 — Photo + numbered badge overlays ─────────────────────
            _MealPhotoWithBadges(
              imageBytes: imageBytes,
              steps: result.eatingSequence,
              positions: _overlayPositions,
            ),

            // ── L6.3 + L6.4 — Step list + spike comparison ─────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Detected items row
                    _DetectedItemsRow(items: result.detectedItems),
                    const SizedBox(height: 16),

                    // Step list — L6.3
                    const _SectionLabel('Eating Order'),
                    const SizedBox(height: 8),
                    ...result.eatingSequence
                        .map((s) => _StepCard(step: s)),

                    const SizedBox(height: 20),

                    // Spike comparison — L6.4
                    const _SectionLabel('Glucose Impact'),
                    const SizedBox(height: 8),
                    _SpikeComparisonRow(result: result),

                    const SizedBox(height: 24),

                    // CTA — L6.4
                    _StartEatingButton(result: result),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo with numbered badge overlays ────────────────────────────────────────

class _MealPhotoWithBadges extends StatelessWidget {
  final Uint8List imageBytes;
  final List<EatingStep> steps;
  final List<Offset> positions;

  const _MealPhotoWithBadges({
    required this.imageBytes,
    required this.steps,
    required this.positions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const height = 240.0;
      final width = constraints.maxWidth;

      return SizedBox(
        height: height,
        width: width,
        child: Stack(
          children: [
            // Photo
            Positioned.fill(
              child: Image.memory(imageBytes, fit: BoxFit.cover),
            ),
            // Dark gradient at bottom for legibility
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                  ),
                ),
              ),
            ),
            // Numbered badges
            ...steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final pos = i < positions.length
                  ? positions[i]
                  : Offset(0.5, 0.5);
              return Positioned(
                left: pos.dx * width - 18,
                top: pos.dy * height - 18,
                child: _StepBadge(
                  number: step.step,
                  emoji: step.categoryEmoji,
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

class _StepBadge extends StatelessWidget {
  final int number;
  final String emoji;
  const _StepBadge({required this.number, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: GlucoNavColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

// ── Detected items strip ──────────────────────────────────────────────────────

class _DetectedItemsRow extends StatelessWidget {
  final List<DetectedItem> items;
  const _DetectedItemsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items
          .map((item) => Chip(
                label: Text(
                  '${item.label}  ${(item.confidence * 100).round()}%',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: GlucoNavColors.surfaceVariant,
                side: const BorderSide(color: GlucoNavColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ))
          .toList(),
    );
  }
}

// ── Step list card — L6.3 ────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final EatingStep step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: GlucoNavColors.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Step number circle
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: GlucoNavColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${step.step}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Food info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(step.categoryEmoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(step.food,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: GlucoNavColors.textPrimary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GlucoNavColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(step.category,
                            style: const TextStyle(
                                fontSize: 10,
                                color: GlucoNavColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(step.reason,
                      style: const TextStyle(
                          fontSize: 12,
                          color: GlucoNavColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Spike comparison cards — L6.4 ────────────────────────────────────────────

class _SpikeComparisonRow extends StatelessWidget {
  final SequenceResult result;
  const _SpikeComparisonRow({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SpikeCard(
            label: 'Without order',
            value: '+${result.spikeWithoutOrderMgDl} mg/dL',
            sublabel: 'random eating',
            color: GlucoNavColors.spikeHigh,
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SpikeCard(
            label: 'With order',
            value: '+${result.spikeWithOrderMgDl} mg/dL',
            sublabel: '${result.reductionPercent}% reduction 🎉',
            color: GlucoNavColors.spikeLow,
            icon: Icons.trending_down,
          ),
        ),
      ],
    );
  }
}

class _SpikeCard extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final Color color;
  final IconData icon;

  const _SpikeCard({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 4),
          Text(sublabel,
              style: const TextStyle(
                  fontSize: 11, color: GlucoNavColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── "Start Eating!" CTA — L6.4 ───────────────────────────────────────────────

class _StartEatingButton extends StatelessWidget {
  final SequenceResult result;
  const _StartEatingButton({required this.result});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // Start 20-min post-meal timer and go back, or push Activity screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '🍽️ Enjoy your meal! Activity reminder in 20 minutes.'),
              backgroundColor: GlucoNavColors.primary,
              duration: Duration(seconds: 4),
            ),
          );
          // Navigate to activity snack with a short demo timer (20 min real)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ActivitySnackScreen(
                exerciseName: 'Brisk Walk',
                durationMinutes: 10,
                glucoseBenefitMgDl: 20,
                exerciseId: 'ex_001',
                spikeRisk: 'medium',
                timerMinutes: 20, // real timer — 20 min post meal
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: GlucoNavColors.primary,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Start Eating!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Text('🥗', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: GlucoNavColors.textPrimary));
  }
}
