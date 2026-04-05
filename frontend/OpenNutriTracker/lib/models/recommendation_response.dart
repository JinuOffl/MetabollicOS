/// Models for the GET /api/v1/recommend/{user_id} response.

class DietRecommendation {
  final String mealId;
  final String name;
  final String? cuisine;
  final double? predictedGlucoseDelta; // mg/dL spike
  final double? gi;
  final String? reason;
  final List<String> tags;

  final String? insulinDose;   // ← NEW: "4.5 units" or null
  final double? carbsG;        // ← NEW: grams of carbs
  final String? imageUrl;      // ← NEW

  const DietRecommendation({
    required this.mealId,
    required this.name,
    this.cuisine,
    this.predictedGlucoseDelta,
    this.gi,
    this.reason,
    this.tags = const [],
    this.insulinDose,           // ← NEW
    this.carbsG,                // ← NEW
    this.imageUrl,              // ← NEW
  });

  factory DietRecommendation.fromJson(Map<String, dynamic> j) =>
      DietRecommendation(
        mealId: j['meal_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        cuisine: j['cuisine'] as String?,
        predictedGlucoseDelta:
            (j['predicted_glucose_delta'] as num?)?.toDouble(),
        gi: (j['gi'] as num?)?.toDouble(),
        reason: j['reason'] as String?,
        tags: ((j['tags'] as List?) ?? []).cast<String>(),
        insulinDose: j['insulin_dose'] as String?,   // ← NEW
        carbsG: (j['carbs_g'] as num?)?.toDouble(),  // ← NEW
        imageUrl: j['image_url'] as String?,         // ← NEW
      );

  /// Spike colour: < 30 green, 30-60 amber, > 60 red.
  bool get isLowSpike => (predictedGlucoseDelta ?? 99) < 35;
}

class ExerciseRecommendation {
  final String exerciseId;
  final String name;
  final String? type;
  final int? durationMinutes;
  final double? glucoseBenefitMgDl;
  final int? burnoutCost;
  final String? reason;
  final String timing;

  const ExerciseRecommendation({
    required this.exerciseId,
    required this.name,
    this.type,
    this.durationMinutes,
    this.glucoseBenefitMgDl,
    this.burnoutCost,
    this.reason,
    this.timing = 'post_meal',
  });

  factory ExerciseRecommendation.fromJson(Map<String, dynamic> j) =>
      ExerciseRecommendation(
        exerciseId: j['exercise_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String?,
        durationMinutes: j['duration_minutes'] as int?,
        glucoseBenefitMgDl:
            (j['glucose_benefit_mg_dl'] as num?)?.toDouble(),
        burnoutCost: j['burnout_cost'] as int?,
        reason: j['reason'] as String?,
        timing: j['timing'] as String? ?? 'post_meal',
      );
}

class RecommendResponse {
  final String? userId;
  final List<DietRecommendation> dietRecommendations;
  final List<ExerciseRecommendation> exerciseRecommendations;
  final String spikeRisk;   // "low" | "medium" | "high"
  final String coachMode;   // "active" | "balanced" | "supportive"
  final double burnoutScore; // 0.0–10.0
  final String? contextWarning;
  final double? currentGlucose;

  const RecommendResponse({
    this.userId,
    required this.dietRecommendations,
    required this.exerciseRecommendations,
    this.spikeRisk = 'medium',
    this.coachMode = 'active',
    this.burnoutScore = 0,
    this.contextWarning,
    this.currentGlucose,
  });

  factory RecommendResponse.fromJson(Map<String, dynamic> j) =>
      RecommendResponse(
        userId: j['user_id'] as String?,
        dietRecommendations:
            (((j['diet_recommendations'] ?? j['diet_list']) as List?) ?? [])
                .map((e) =>
                    DietRecommendation.fromJson(e as Map<String, dynamic>))
                .toList(),
        exerciseRecommendations:
            (((j['exercise_recommendations'] ?? j['exercise_list'])
                        as List?) ??
                    [])
                .map((e) =>
                    ExerciseRecommendation.fromJson(e as Map<String, dynamic>))
                .toList(),
        spikeRisk: j['spike_risk'] as String? ?? 'medium',
        coachMode: j['coach_mode'] as String? ?? 'active',
        burnoutScore:
            (j['burnout_score'] as num?)?.toDouble() ?? 0.0,
        contextWarning: j['context_warning'] as String?,
        currentGlucose: (j['current_glucose'] as num?)?.toDouble(),
      );
}
