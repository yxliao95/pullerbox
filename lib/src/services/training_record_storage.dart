import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_record.dart';

class TrainingRecordStorage {
  static const String storageKey = 'training_history_v1';

  Future<TrainingRecordSnapshot?> loadHistory() async {
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
      return TrainingRecordSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHistory(TrainingRecordSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(snapshot.toJson());
    await prefs.setString(storageKey, payload);
  }
}
