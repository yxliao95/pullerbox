import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_plan.dart';

class TrainingPlanStorage {
  static const String storageKey = 'training_plan_library_v1';

  Future<TrainingPlanLibrarySnapshot?> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return TrainingPlanLibrarySnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLibrary(TrainingPlanLibrarySnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(snapshot.toJson());
    await prefs.setString(storageKey, payload);
  }
}
