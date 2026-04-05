import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recommendation_response.dart';
import '../models/sequence_result.dart';

// ── Phase 6.5 Integration ─────────────────────────────────────────────────────
//
// Integration strategy: real API first, mock fallback if backend unreachable.
// This means the demo works even if the ML models aren't loaded yet.
//
// To switch demo users:
//   GlucoNavApiService.userId = 'demo_user_new';          // generic recs
//   GlucoNavApiService.userId = 'demo_user_experienced';  // personalised recs
//
// To force mock mode (no backend):
//   GlucoNavApiService.forceMock = true;
// ─────────────────────────────────────────────────────────────────────────────

class GlucoNavApiService {
  static const String _base = 'http://localhost:8000/api/v1';

  /// Active user ID. Set during onboarding; defaults to demo_user_experienced.
  static String userId = 'demo_user_experienced';

  /// When true, all calls use mock data (for offline demo / testing).
  static bool forceMock = false;

  // ── Init from SharedPreferences ───────────────────────────────────────────

  /// Call once in main() before runApp(). Loads persisted user_id.
  static Future<void> initUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id') ?? 'demo_user_experienced';
    } catch (_) {
      userId = 'demo_user_experienced';
    }
  }

  /// Persist user_id after onboarding.
  static Future<void> setUserId(String id) async {
    userId = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', id);
    } catch (_) {}
  }

  // ── Health check ──────────────────────────────────────────────────────────

  Future<bool> isBackendAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('http://localhost:8000/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Recommendations (real → mock fallback) ────────────────────────────────

  /// Primary method used by the BLoC. Tries real API; falls back to mock.
  Future<RecommendResponse> fetchRecommendations({
    double? sleepScore,
    double? currentGlucose,
    int? steps,
  }) async {
    if (forceMock) return getRecommendationsMock();
    try {
      return await getRecommendations(
        userId,
        sleepScore: sleepScore,
        currentGlucose: currentGlucose,
        steps: steps,
      );
    } catch (e) {
      // Backend unreachable or error — fall back to rich mock
      return getRecommendationsMock();
    }
  }

  // ── Meal analysis (real → mock fallback, web-compatible) ─────────────────

  /// Web-compatible: sends raw bytes instead of dart:io File.
  /// Tries real API; falls back to mock if backend is unreachable.
  Future<SequenceResult> analyzeImageBytes(Uint8List bytes) async {
    if (forceMock) return analyzeMealMock(bytes);
    try {
      final req =
          http.MultipartRequest('POST', Uri.parse('$_base/analyze-meal'));
      req.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: 'meal.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        return SequenceResult.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
      throw Exception('analyze-meal returned ${res.statusCode}');
    } catch (_) {
      return analyzeMealMock(bytes);
    }
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  Future<String?> onboardUser({
    required String diabetesType,
    required String hbA1cBand,
    required String cuisinePreference,
    required String dietType,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/users/onboard'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'diabetes_type': diabetesType,
          'hba1c_band': hbA1cBand,
          'cuisine_preference': cuisinePreference,
          'diet_type': dietType,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newId = data['user_id'] as String;
        await setUserId(newId);
        return newId;
      }
    } catch (_) {}
    return null;
  }

  // ── Feedback (fire-and-forget, errors silenced) ───────────────────────────

  Future<void> logFeedback({
    String? userIdOverride,
    required String itemId,
    required String itemType,
    required String interactionType,
  }) async {
    try {
      await http.post(
        Uri.parse('$_base/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userIdOverride ?? userId,
          'item_id': itemId,
          'item_type': itemType,
          'interaction_type': interactionType,
        }),
      );
    } catch (_) {} // Non-critical — silenced
  }

  Future<void> logGlucose({double? glucoseMgDl}) async {
    if (glucoseMgDl == null) return;
    try {
      await http.post(
        Uri.parse('$_base/glucose-reading'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'glucose_mgdl': glucoseMgDl,
        }),
      );
    } catch (_) {}
  }

  // ── Real API calls (used internally above) ────────────────────────────────

  Future<RecommendResponse> getRecommendations(
    String uid, {
    double? sleepScore,
    double? currentGlucose,
    int? steps,
  }) async {
    final params = {
      if (sleepScore != null) 'sleep_score': sleepScore.toString(),
      if (currentGlucose != null) 'current_glucose': currentGlucose.toString(),
      if (steps != null) 'steps': steps.toString(),
    };
    final uri =
        Uri.parse('$_base/recommend/$uid').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return RecommendResponse.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Recommend failed: ${res.statusCode}');
  }

  // ── Mock data (kept as fallback and for offline demo) ─────────────────────

  Future<RecommendResponse> getRecommendationsMock() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return RecommendResponse.fromJson(Map<String, dynamic>.from(_mockRecommend));
  }

  Future<SequenceResult> analyzeMealMock(List<int> imageBytes) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return SequenceResult.fromJson(Map<String, dynamic>.from(_mockSequence));
  }
}

// ── Mock JSON ─────────────────────────────────────────────────────────────────
// Kept as rich fallback — matches exact shape of real API response.
// Demo tips:
//   spike_risk  → "high" to show urgency banner (L7.4)
//   coach_mode  → "balanced" / "supportive" to demo L8 tone change
// ─────────────────────────────────────────────────────────────────────────────

const _mockRecommend = {
  'user_id': 'demo_user_experienced',
  'diet_recommendations': [
    {
      'meal_id': 'meal_001',
      'name': 'Idli + Sambar',
      'cuisine': 'South Indian',
      'predicted_glucose_delta': 18.0,
      'gi': 38.0,
      'reason': 'Low-GI; high fibre dampens spike',
      'tags': ['vegetarian', 'south_indian'],
    },
    {
      'meal_id': 'meal_002',
      'name': 'Moong Dal Cheela',
      'cuisine': 'North Indian',
      'predicted_glucose_delta': 22.0,
      'gi': 42.0,
      'reason': 'Low-GI food; moderate fibre; protein-rich',
      'tags': ['vegetarian', 'north_indian'],
    },
    {
      'meal_id': 'meal_003',
      'name': 'Ragi Dosa',
      'cuisine': 'South Indian',
      'predicted_glucose_delta': 25.0,
      'gi': 45.0,
      'reason': 'Low-GI food; high fibre from ragi (finger millet)',
      'tags': ['vegetarian', 'south_indian'],
    },
  ],
  'exercise_recommendations': [
    {
      'exercise_id': 'ex_001',
      'name': 'Brisk Walk',
      'type': 'cardio',
      'duration_minutes': 10,
      'glucose_benefit_mg_dl': 20.0,
      'burnout_cost': 2,
      'reason': 'Ideal post-meal exercise; minimal effort required',
      'timing': 'post_meal',
    },
    {
      'exercise_id': 'ex_002',
      'name': 'Chair Squats',
      'type': 'strength',
      'duration_minutes': 5,
      'glucose_benefit_mg_dl': 15.0,
      'burnout_cost': 2,
      'reason': 'Activates large leg muscles; very low burnout cost',
      'timing': 'post_meal',
    },
  ],
  'spike_risk': 'medium',
  'coach_mode': 'active',
  'burnout_score': 2.5,
  'context_warning': null,
};

const _mockSequence = {
  'detected_items': [
    {'label': 'Idli',    'confidence': 0.91},
    {'label': 'Sambar',  'confidence': 0.76},
    {'label': 'Chutney', 'confidence': 0.55},
  ],
  'eating_sequence': [
    {
      'step': 1,
      'food': 'Sambar',
      'category': 'Fiber',
      'reason': 'Start with lentil broth — fibre slows glucose absorption',
    },
    {
      'step': 2,
      'food': 'Chutney',
      'category': 'Fat',
      'reason': 'Coconut fat further dampens the post-meal spike',
    },
    {
      'step': 3,
      'food': 'Idli',
      'category': 'Carb',
      'reason': 'Eat carbs last — your body handles them 64% better now',
    },
  ],
  'spike_without_order_mg_dl': 67,
  'spike_with_order_mg_dl': 24,
  'reduction_percent': 64,
};
