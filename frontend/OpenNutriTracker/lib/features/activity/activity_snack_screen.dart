import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/gluconav_colors.dart';
import '../../services/gluconav_api_service.dart';
import 'activity_snack_bloc.dart';

/// L7.2 — Activity Snack screen: exercise card with glucose-benefit badge.
/// L7.3 — "Done!" → logFeedback → streak +1 via BLoC.
/// L7.4 — spike_risk drives urgency label colour and copy.
///
/// Receives [timerMinutes] from caller. When timer hits 0 → card is revealed.
/// For demo: pass timerMinutes = 0 to show card immediately.
///          Pass timerMinutes = 20 for the real 20-min post-meal flow.
class ActivitySnackScreen extends StatelessWidget {
  final String exerciseName;
  final int durationMinutes;
  final double glucoseBenefitMgDl;
  final String exerciseId;
  final String spikeRisk; // "low" | "medium" | "high"
  final int timerMinutes; // 0 = show card immediately (demo shortcut)

  const ActivitySnackScreen({
    super.key,
    required this.exerciseName,
    required this.durationMinutes,
    required this.glucoseBenefitMgDl,
    required this.exerciseId,
    this.spikeRisk = 'medium',
    this.timerMinutes = 20,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = ActivitySnackBloc();
        if (timerMinutes > 0) {
          bloc.add(StartActivityTimer(minutes: timerMinutes));
        }
        // timerMinutes == 0 → BLoC starts in ActivityReady state
        return bloc;
      },
      child: _ActivitySnackView(
        exerciseName: exerciseName,
        durationMinutes: durationMinutes,
        glucoseBenefitMgDl: glucoseBenefitMgDl,
        exerciseId: exerciseId,
        spikeRisk: spikeRisk,
      ),
    );
  }
}

class _ActivitySnackView extends StatelessWidget {
  final String exerciseName;
  final int durationMinutes;
  final double glucoseBenefitMgDl;
  final String exerciseId;
  final String spikeRisk;

  const _ActivitySnackView({
    required this.exerciseName,
    required this.durationMinutes,
    required this.glucoseBenefitMgDl,
    required this.exerciseId,
    required this.spikeRisk,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivitySnackBloc, ActivitySnackState>(
      listener: (context, state) {
        if (state is ActivityCompleted) {
          // L7.3 — log feedback to backend (fire-and-forget)
          GlucoNavApiService().logFeedback(
            userId: 'demo_user_experienced',
            itemId: exerciseId,
            itemType: 'exercise',
            interactionType: 'completed',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '🔥 Streak: ${state.newStreakDays} days! Glucose spike flattened.'),
              backgroundColor: GlucoNavColors.primary,
              duration: const Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(seconds: 3), () {
            if (context.mounted) Navigator.pop(context);
          });
        }
        if (state is ActivitySkipped) {
          GlucoNavApiService().logFeedback(
            userId: 'demo_user_experienced',
            itemId: exerciseId,
            itemType: 'exercise',
            interactionType: 'skipped',
          );
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: GlucoNavColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Activity Snack',
              style: TextStyle(
                  color: GlucoNavColors.primary, fontWeight: FontWeight.bold),
            ),
            leading: const BackButton(color: GlucoNavColors.primary),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildBody(context, state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ActivitySnackState state) {
    // ── Counting down ──────────────────────────────────────────────────────
    if (state is ActivityCountingDown) {
      return _CountdownView(state: state);
    }

    // ── Completed ─────────────────────────────────────────────────────────
    if (state is ActivityCompleted) {
      return _CompletedView(streakDays: state.newStreakDays);
    }

    // ── Ready (timer elapsed or timerMinutes == 0) ─────────────────────────
    return _ExerciseCardView(
      exerciseName: exerciseName,
      durationMinutes: durationMinutes,
      glucoseBenefitMgDl: glucoseBenefitMgDl,
      spikeRisk: spikeRisk,
      onDone: () =>
          context.read<ActivitySnackBloc>().add(const CompleteActivitySnack()),
      onSkip: () =>
          context.read<ActivitySnackBloc>().add(const SkipActivitySnack()),
    );
  }
}

// ── Countdown view ────────────────────────────────────────────────────────────

class _CountdownView extends StatelessWidget {
  final ActivityCountingDown state;
  const _CountdownView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '⏱️ Post-meal rest',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: GlucoNavColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your Activity Snack will be ready in…',
          style:
              TextStyle(fontSize: 14, color: GlucoNavColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Circular progress ring
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: state.progress,
                  strokeWidth: 10,
                  color: GlucoNavColors.primary,
                  backgroundColor:
                      GlucoNavColors.primary.withOpacity(0.12),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.displayTime,
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: GlucoNavColors.primary,
                        fontFeatures: []),
                  ),
                  const Text(
                    'remaining',
                    style: TextStyle(
                        fontSize: 12, color: GlucoNavColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          '💡 Tip: A short walk after meals reduces\nglucose absorption by up to 30%',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: GlucoNavColors.textSecondary),
        ),
        const SizedBox(height: 30),
        // Demo shortcut — long press to skip timer
        GestureDetector(
          onLongPress: () => context
              .read<ActivitySnackBloc>()
              .add(const _TimerTick(0)), // force to 0
          child: const Text(
            '(Long press to skip timer — demo mode)',
            style: TextStyle(fontSize: 10, color: GlucoNavColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _TimerTick extends ActivitySnackEvent {
  final int remaining;
  const _TimerTick(this.remaining);
  @override
  List<Object?> get props => [remaining];
}

// ── Exercise card view ────────────────────────────────────────────────────────

class _ExerciseCardView extends StatelessWidget {
  final String exerciseName;
  final int durationMinutes;
  final double glucoseBenefitMgDl;
  final String spikeRisk;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const _ExerciseCardView({
    required this.exerciseName,
    required this.durationMinutes,
    required this.glucoseBenefitMgDl,
    required this.spikeRisk,
    required this.onDone,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🏃 Time for your Activity Snack!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: GlucoNavColors.textPrimary),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text('20 minutes post-meal — perfect timing',
            style: TextStyle(
                fontSize: 13, color: GlucoNavColors.textSecondary)),
        const SizedBox(height: 32),

        // ── L7.4 — spike_risk urgency banner ─────────────────────────────
        _UrgencyBanner(spikeRisk: spikeRisk),
        const SizedBox(height: 20),

        // ── Exercise card ─────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GlucoNavColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: GlucoNavColors.primary.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: GlucoNavColors.primary.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Glucose benefit badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: GlucoNavColors.spikeLow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '−${glucoseBenefitMgDl.round()} mg/dL glucose benefit',
                  style: const TextStyle(
                      color: GlucoNavColors.spikeLow,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Exercise icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: GlucoNavColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🚶', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 16),

              // Exercise name
              Text(
                exerciseName,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: GlucoNavColors.textPrimary),
              ),
              const SizedBox(height: 6),

              // Duration
              Text(
                '$durationMinutes minutes',
                style: const TextStyle(
                    fontSize: 16, color: GlucoNavColors.textSecondary),
              ),
              const SizedBox(height: 8),
              const Text(
                'A quick walk now flattens your\npost-meal glucose spike',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: GlucoNavColors.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── L7.3 — Done! button ────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlucoNavColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Done! 🔥',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Skip link
        TextButton(
          onPressed: onSkip,
          child: const Text(
            'Skip for today',
            style: TextStyle(
                color: GlucoNavColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// L7.4 — Urgency level driven by spike_risk field.
class _UrgencyBanner extends StatelessWidget {
  final String spikeRisk;
  const _UrgencyBanner({required this.spikeRisk});

  @override
  Widget build(BuildContext context) {
    if (spikeRisk == 'low') return const SizedBox.shrink();

    final isHigh = spikeRisk == 'high';
    final color = isHigh ? GlucoNavColors.spikeHigh : const Color(0xFFEA8C00);
    final icon = isHigh ? '🔴' : '🟡';
    final text = isHigh
        ? 'High spike risk — movement is especially important now!'
        : 'Moderate spike risk — a short walk will help a lot';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Completed view ────────────────────────────────────────────────────────────

class _CompletedView extends StatelessWidget {
  final int streakDays;
  const _CompletedView({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('✅', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 20),
        const Text('Activity complete!',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: GlucoNavColors.textPrimary)),
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: GlucoNavColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streakDays days',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: GlucoNavColors.primary),
                  ),
                  const Text('streak',
                      style: TextStyle(
                          color: GlucoNavColors.textSecondary,
                          fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your glucose spike is being\nflattened right now 📉',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: GlucoNavColors.textSecondary),
        ),
      ],
    );
  }
}
