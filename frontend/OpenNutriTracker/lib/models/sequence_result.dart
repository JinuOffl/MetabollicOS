/// Models for the POST /api/v1/analyze-meal response.

class DetectedItem {
  final String label;
  final double confidence;

  const DetectedItem({required this.label, required this.confidence});

  factory DetectedItem.fromJson(Map<String, dynamic> j) => DetectedItem(
        label: j['label'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

class EatingStep {
  final int step;
  final String food;
  final String category; // Fiber | Protein | Fat | Carb
  final String reason;

  const EatingStep({
    required this.step,
    required this.food,
    required this.category,
    required this.reason,
  });

  factory EatingStep.fromJson(Map<String, dynamic> j) => EatingStep(
        step: j['step'] as int? ?? 0,
        food: j['food'] as String? ?? '',
        category: j['category'] as String? ?? 'Carb',
        reason: j['reason'] as String? ?? '',
      );

  /// Emoji prefix for category badge.
  String get categoryEmoji {
    switch (category) {
      case 'Fiber':   return '🥗';
      case 'Protein': return '🥩';
      case 'Fat':     return '🥑';
      default:        return '🍚';
    }
  }
}

class SequenceResult {
  final List<DetectedItem> detectedItems;
  final List<EatingStep> eatingSequence;
  final int spikeWithoutOrderMgDl;
  final int spikeWithOrderMgDl;
  final int reductionPercent;

  const SequenceResult({
    required this.detectedItems,
    required this.eatingSequence,
    required this.spikeWithoutOrderMgDl,
    required this.spikeWithOrderMgDl,
    required this.reductionPercent,
  });

  factory SequenceResult.fromJson(Map<String, dynamic> j) => SequenceResult(
        detectedItems: ((j['detected_items'] as List?) ?? [])
            .map((e) => DetectedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        eatingSequence: ((j['eating_sequence'] as List?) ?? [])
            .map((e) => EatingStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        spikeWithoutOrderMgDl: j['spike_without_order_mg_dl'] as int? ?? 67,
        spikeWithOrderMgDl: j['spike_with_order_mg_dl'] as int? ?? 28,
        reductionPercent: j['reduction_percent'] as int? ?? 58,
      );
}
