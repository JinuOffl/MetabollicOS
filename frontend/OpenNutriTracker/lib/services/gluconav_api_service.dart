import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';import 'package:http/http.dart' as http;
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
  // Use localhost for same-machine Chrome demo (flutter run -d chrome)
  // Change to your WiFi IP if testing from a separate device
  static String _base = 'http://localhost:8000/api/v1';

  /// Active user ID. Set during onboarding; defaults to demo_user_experienced.
  static String userId = 'demo_user_experienced';

  /// When true, all calls use mock data (for offline demo / testing).
  static bool forceMock = false;

  // ── Init from SharedPreferences ───────────────────────────────────────────

  /// Call once in main() before runApp(). Loads persisted user_id. Returns true if user exists.
  static Future<bool> initUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('user_id');
      if (savedId != null && savedId.isNotEmpty) {
        userId = savedId;
        // Restore server config if saved
        final savedIp   = prefs.getString('server_ip');
        final savedPort = prefs.getString('server_port') ?? '8000';
        if (savedIp != null && savedIp.isNotEmpty) {
          _base = 'http://$savedIp:$savedPort/api/v1';
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Persist user_id after onboarding.
  static Future<void> setUserId(String id) async {
    userId = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', id);
    } catch (_) {}
  }

  /// Update the backend IP and port at runtime (from CGM Connect dialog).
  static Future<void> setServerConfig({required String ip, String port = '8000'}) async {
    _base = 'http://$ip:$port/api/v1';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', ip);
      await prefs.setString('server_port', port);
    } catch (_) {}
  }

  // ── Health check ──────────────────────────────────────────────────────────

  Future<bool> isBackendAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('${_base.replaceAll('/api/v1', '')}/health'))
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
    } on SocketException catch (_) {
      // Backend is truly offline — use mock so demo still works
      return getRecommendationsMock();
    } on TimeoutException catch (_) {
      // Backend too slow — use mock
      return getRecommendationsMock();
    } catch (e) {
      // Other errors (404, 500): log but still mock to not crash demo
      // ignore: avoid_print
      debugPrint('⚠️ GlucoNav API error: $e — serving mock data');
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

  /// Sends glucometer photo to backend → extracts glucose value → logs it.
  /// Returns the extracted glucose value (mg/dL) or null if extraction failed.
  Future<double?> analyzeGlucometerBytes(Uint8List bytes) async {
    try {
      final uri = Uri.parse('$_base/analyze-glucometer').replace(
        queryParameters: {'user_id': userId},
      );
      final req = http.MultipartRequest('POST', uri);
      req.files.add(
        http.MultipartFile.fromBytes(
          'image', bytes,
          filename: 'glucometer.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final glucoseValue = (data['glucose_mgdl'] as num?)?.toDouble();
        if (glucoseValue != null) {
          // Also log it to the DB via the standard glucose-reading endpoint
          await logGlucose(glucoseMgDl: glucoseValue);
        }
        return glucoseValue;
      }
    } catch (e) {
      debugPrint('⚠️ Glucometer API error: $e');
    }
    return null; // Return null so CameraScreen can show a proper error message
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  Future<String?> onboardUser(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/users/onboard'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newId = data['user_id'] as String;
        await setUserId(newId);
        return newId;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (forceMock) return _mockUserProfile;
    try {
      final res = await http.get(Uri.parse('$_base/users/$userId'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return _mockUserProfile;
  }

  Future<Map<String, dynamic>?> getUserStats() async {
    if (forceMock) return _mockUserStats;
    try {
      final res = await http.get(Uri.parse('$_base/users/$userId/stats'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return _mockUserStats;
  }

  static const _mockUserStats = {
    'user_id': 'demo_user_experienced',
    'streak_days': 14,
    'time_in_range_pct': 71.0,
    'avg_glucose_mgdl': 118.0,
    'avg_post_meal_spike': 22.0,
    'activities_done_7d': 9,
    'total_glucose_readings': 28,
  };

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

// NOTE: This mock has 3 items (Idli, Sambar, Chutney). Real responses are dynamic
// and will have as many steps as the number of foods detected in the photo.
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

const _mockUserProfile = {
  "user_id": "demo_user_experienced",
  "profile": {
    "diabetes_type": "type2",
    "hba1c_band": "moderate",
    "cuisine_preference": "south_indian",
    "diet_type": "vegetarian",
    "age": 32,
    "weight_kg": 72.5,
    "height_cm": 175.0,
    "gender": "male",
    "goal": "lose_weight",
    "activity_level": "light"
  }
};
