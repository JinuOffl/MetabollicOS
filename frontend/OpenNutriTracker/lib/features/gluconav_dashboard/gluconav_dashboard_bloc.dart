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

  const DashboardLoaded({required this.response, this.streakDays = 12});

  DashboardLoaded copyWith({RecommendResponse? response, int? streakDays}) =>
      DashboardLoaded(
        response: response ?? this.response,
        streakDays: streakDays ?? this.streakDays,
      );

  @override
  List<Object?> get props => [response, streakDays];
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
  double? _lastGlucose;

  GlucoNavDashboardBloc(this._api) : super(const DashboardLoading()) {
    on<LoadDashboard>(_onLoad);
    on<UpdateContext>(_onUpdateContext);
    on<IncrementStreak>(_onIncrementStreak);
  }

  Future<void> _onLoad(
      LoadDashboard event, Emitter<GlucoNavDashboardState> emit) async {
    emit(const DashboardLoading());
    try {
      // I1.1 — uses fetchRecommendations() which tries real API then falls back
      final response = await _api.fetchRecommendations(
        sleepScore: _lastSleepScore,
        currentGlucose: _lastGlucose,
      );
      final streak =
          state is DashboardLoaded ? (state as DashboardLoaded).streakDays : 12;
      emit(DashboardLoaded(response: response, streakDays: streak));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onUpdateContext(
      UpdateContext event, Emitter<GlucoNavDashboardState> emit) async {
    // Cache context values for subsequent LoadDashboard calls
    if (event.sleepScore != null) _lastSleepScore = event.sleepScore;
    if (event.currentGlucose != null) _lastGlucose = event.currentGlucose;

    try {
      // I1.1 — pass context to real API so spike_risk updates live
      final response = await _api.fetchRecommendations(
        sleepScore: _lastSleepScore,
        currentGlucose: _lastGlucose,
      );
      final streak =
          state is DashboardLoaded ? (state as DashboardLoaded).streakDays : 12;
      emit(DashboardLoaded(response: response, streakDays: streak));
    } catch (e) {
      // Don't show error on context update — keep existing state
    }
  }

  void _onIncrementStreak(
      IncrementStreak event, Emitter<GlucoNavDashboardState> emit) {
    if (state is DashboardLoaded) {
      final loaded = state as DashboardLoaded;
      emit(loaded.copyWith(streakDays: loaded.streakDays + 1));
    }
  }
}
