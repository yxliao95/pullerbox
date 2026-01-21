import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/free_training_record.dart';

class FreeTrainingRecordStorage {
  static const String storageKey = 'free_training_history_v1';

  Future<FreeTrainingRecordSnapshot?> loadHistory() async {
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
      return FreeTrainingRecordSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHistory(FreeTrainingRecordSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(snapshot.toJson());
    await prefs.setString(storageKey, payload);
  }
}
