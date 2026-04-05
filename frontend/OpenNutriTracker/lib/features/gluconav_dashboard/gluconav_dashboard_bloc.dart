import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/recommendation_response.dart';
import '../../services/gluconav_api_service.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class GlucoNavDashboardEvent extends Equatable {
  const GlucoNavDashboardEvent();
  @override
  List<Object?> get props => [];
}

class LoadDashboard extends GlucoNavDashboardEvent {
  const LoadDashboard();
}

/// Internal event fired every 10s to sync CGM data without showing a spinner.
class DashboardPulse extends GlucoNavDashboardEvent {
  const DashboardPulse();
}

/// Sent when user adjusts sleep slider or glucose field.
/// Triggers a re-fetch with context params so spike_risk updates live.
class UpdateContext extends GlucoNavDashboardEvent {
  final double? sleepScore;
  final double? currentGlucose;
  const UpdateContext({this.sleepScore, this.currentGlucose});
  @override
  List<Object?> get props => [sleepScore, currentGlucose];
}

class IncrementStreak extends GlucoNavDashboardEvent {
  const IncrementStreak();
}

// ── States ────────────────────────────────────────────────────────────────────

abstract class GlucoNavDashboardState extends Equatable {
  const GlucoNavDashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardLoading extends GlucoNavDashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends GlucoNavDashboardState {
  final RecommendResponse response;
  final int streakDays;
  final bool isLiveData; // true = real API, false = mock fallback

  const DashboardLoaded({
    required this.response,
    this.streakDays = 12,
    this.isLiveData = false,
  });

  DashboardLoaded copyWith({
    RecommendResponse? response,
    int? streakDays,
    bool? isLiveData,
  }) =>
      DashboardLoaded(
        response: response ?? this.response,
        streakDays: streakDays ?? this.streakDays,
        isLiveData: isLiveData ?? this.isLiveData,
      );

  @override
  List<Object?> get props => [response, streakDays, isLiveData];
}

class DashboardError extends GlucoNavDashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class GlucoNavDashboardBloc
    extends Bloc<GlucoNavDashboardEvent, GlucoNavDashboardState> {
  final GlucoNavApiService _api;

  // Cache last context values so UpdateContext can send them to the API
  double? _lastSleepScore;
  double? _lastKnownGlucose; // set whenever a CGM reading arrives

  Timer? _pulseTimer;

  GlucoNavDashboardBloc(this._api) : super(const DashboardLoading()) {
    on<LoadDashboard>(_onLoad);
    on<DashboardPulse>(_onPulse);
    on<UpdateContext>(_onUpdateContext);
    on<IncrementStreak>(_onIncrementStreak);

    // K5.2 — Start periodic pulse to sync CGM simulator data
    _pulseTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!isClosed) add(const DashboardPulse());
    });
  }

  @override
  Future<void> close() {
    _pulseTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
      LoadDashboard event, Emitter<GlucoNavDashboardState> emit) async {
    emit(const DashboardLoading());
    bool isLive = false;
    RecommendResponse response;
    try {
      // Directly call the real API (not fetchRecommendations) so we can
      // distinguish success (isLive=true) from mock fallback (isLive=false).
      response = await _api.getRecommendations(
        GlucoNavApiService.userId,
        sleepScore: _lastSleepScore,
        currentGlucose: _lastKnownGlucose,
      );
      isLive = true;
    } catch (_) {
      response = await _api.getRecommendationsMock();
      isLive = false;
    }
    if (response.currentGlucose != null) {
      _lastKnownGlucose = response.currentGlucose;
    }
    final streak =
        state is DashboardLoaded ? (state as DashboardLoaded).streakDays : 12;
    emit(DashboardLoaded(
      response: response,
      streakDays: streak,
      isLiveData: isLive,
    ));
  }

  Future<void> _onPulse(
      DashboardPulse event, Emitter<GlucoNavDashboardState> emit) async {
    // Silent refresh — don't emit Loading state
    if (state is! DashboardLoaded) return;
    bool isLive = false;
    RecommendResponse response;
    try {
      response = await _api.getRecommendations(
        GlucoNavApiService.userId,
        sleepScore: _lastSleepScore,
        currentGlucose: _lastKnownGlucose,
      );
      isLive = true;
    } catch (_) {
      response = await _api.getRecommendationsMock();
      isLive = false;
    }
    if (response.currentGlucose != null) {
      _lastKnownGlucose = response.currentGlucose;
    }
    emit((state as DashboardLoaded).copyWith(
      response: response,
      isLiveData: isLive,
    ));
  }

  Future<void> _onUpdateContext(
      UpdateContext event, Emitter<GlucoNavDashboardState> emit) async {
    // Cache context values for subsequent LoadDashboard calls
    if (event.sleepScore != null) _lastSleepScore = event.sleepScore;
    if (event.currentGlucose != null) _lastKnownGlucose = event.currentGlucose;

    bool isLive = false;
    RecommendResponse response;
    try {
      response = await _api.getRecommendations(
        GlucoNavApiService.userId,
        sleepScore: _lastSleepScore,
        currentGlucose: _lastKnownGlucose,
      );
      isLive = true;
    } catch (_) {
      response = await _api.getRecommendationsMock();
    }
    if (response.currentGlucose != null) {
      _lastKnownGlucose = response.currentGlucose;
    }
    final streak =
        state is DashboardLoaded ? (state as DashboardLoaded).streakDays : 12;
    emit(DashboardLoaded(
      response: response,
      streakDays: streak,
      isLiveData: isLive,
    ));
  }

  void _onIncrementStreak(
      IncrementStreak event, Emitter<GlucoNavDashboardState> emit) {
    if (state is DashboardLoaded) {
      final loaded = state as DashboardLoaded;
      emit(loaded.copyWith(streakDays: loaded.streakDays + 1));
    }
  }
}
