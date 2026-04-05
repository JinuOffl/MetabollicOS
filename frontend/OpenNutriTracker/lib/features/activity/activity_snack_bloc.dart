import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class ActivitySnackEvent extends Equatable {
  const ActivitySnackEvent();
  @override
  List<Object?> get props => [];
}

/// Start the post-meal countdown timer.
class StartActivityTimer extends ActivitySnackEvent {
  final int minutes;
  const StartActivityTimer({required this.minutes});
  @override
  List<Object?> get props => [minutes];
}

/// Internal event — fires every second from the Timer.
class _TimerTick extends ActivitySnackEvent {
  final int remainingSeconds;
  const _TimerTick(this.remainingSeconds);
  @override
  List<Object?> get props => [remainingSeconds];
}

/// User tapped "Done!" after completing the exercise.
class CompleteActivitySnack extends ActivitySnackEvent {
  const CompleteActivitySnack();
}

/// Skip for today.
class SkipActivitySnack extends ActivitySnackEvent {
  const SkipActivitySnack();
}

// ── States ────────────────────────────────────────────────────────────────────

abstract class ActivitySnackState extends Equatable {
  const ActivitySnackState();
  @override
  List<Object?> get props => [];
}

/// Timer counting down; [remainingSeconds] until activity prompt.
class ActivityCountingDown extends ActivitySnackState {
  final int totalSeconds;
  final int remainingSeconds;

  const ActivityCountingDown({
    required this.totalSeconds,
    required this.remainingSeconds,
  });

  double get progress =>
      remainingSeconds / totalSeconds.clamp(1, totalSeconds);

  String get displayTime {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [totalSeconds, remainingSeconds];
}

/// Timer elapsed — time to exercise!
class ActivityReady extends ActivitySnackState {
  const ActivityReady();
}

/// User tapped Done — streak incremented.
class ActivityCompleted extends ActivitySnackState {
  final int newStreakDays;
  const ActivityCompleted(this.newStreakDays);
  @override
  List<Object?> get props => [newStreakDays];
}

/// User skipped.
class ActivitySkipped extends ActivitySnackState {
  const ActivitySkipped();
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class ActivitySnackBloc extends Bloc<ActivitySnackEvent, ActivitySnackState> {
  Timer? _ticker;
  int _streakDays = 12; // default demo streak

  ActivitySnackBloc() : super(const ActivityReady()) {
    on<StartActivityTimer>(_onStart);
    on<_TimerTick>(_onTick);
    on<CompleteActivitySnack>(_onComplete);
    on<SkipActivitySnack>(_onSkip);
  }

  void _onStart(StartActivityTimer event, Emitter<ActivitySnackState> emit) {
    _ticker?.cancel();
    final totalSeconds = event.minutes * 60;
    emit(ActivityCountingDown(
      totalSeconds: totalSeconds,
      remainingSeconds: totalSeconds,
    ));
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      final current = state is ActivityCountingDown
          ? (state as ActivityCountingDown).remainingSeconds
          : 0;
      final next = current - 1;
      if (next <= 0) {
        t.cancel();
        add(const _TimerTick(0));
      } else {
        add(_TimerTick(next));
      }
    });
  }

  void _onTick(_TimerTick event, Emitter<ActivitySnackState> emit) {
    if (event.remainingSeconds <= 0) {
      emit(const ActivityReady());
    } else if (state is ActivityCountingDown) {
      final s = state as ActivityCountingDown;
      emit(ActivityCountingDown(
          totalSeconds: s.totalSeconds,
          remainingSeconds: event.remainingSeconds));
    }
  }

  void _onComplete(
      CompleteActivitySnack event, Emitter<ActivitySnackState> emit) {
    _ticker?.cancel();
    _streakDays++;
    emit(ActivityCompleted(_streakDays));
  }

  void _onSkip(SkipActivitySnack event, Emitter<ActivitySnackState> emit) {
    _ticker?.cancel();
    emit(const ActivitySkipped());
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
