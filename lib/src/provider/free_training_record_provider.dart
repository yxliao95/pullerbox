import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/free_training_record.dart';
import '../services/free_training_record_storage.dart';

class FreeTrainingRecordState {
  const FreeTrainingRecordState({required this.records});

  final List<FreeTrainingRecord> records;

  FreeTrainingRecordState copyWith({List<FreeTrainingRecord>? records}) {
    return FreeTrainingRecordState(records: records ?? this.records);
  }
}

class FreeTrainingRecordController extends Notifier<FreeTrainingRecordState> {
  @override
  FreeTrainingRecordState build() {
    final initialState = const FreeTrainingRecordState(records: <FreeTrainingRecord>[]);
    unawaited(_restoreHistory());
    return initialState;
  }

  Future<void> _restoreHistory() async {
    final snapshot = await ref.read(freeTrainingRecordStorageProvider).loadHistory();
    if (snapshot == null) {
      return;
    }
    if (state.records.isEmpty) {
      state = state.copyWith(records: snapshot.records);
      return;
    }
    final existingIds = state.records.map((record) => record.id).toSet();
    final merged = <FreeTrainingRecord>[
      ...state.records,
      ...snapshot.records.where((record) => !existingIds.contains(record.id)),
    ];
    state = state.copyWith(records: merged);
  }

  Future<void> _persistHistory() async {
    final snapshot = FreeTrainingRecordSnapshot(records: state.records);
    await ref.read(freeTrainingRecordStorageProvider).saveHistory(snapshot);
  }

  void addRecord(FreeTrainingRecord record) {
    state = state.copyWith(records: <FreeTrainingRecord>[record, ...state.records]);
    unawaited(_persistHistory());
  }

  void removeRecord(String recordId) {
    state = state.copyWith(
      records: state.records.where((record) => record.id != recordId).toList(),
    );
    unawaited(_persistHistory());
  }
}

final freeTrainingRecordProvider =
    NotifierProvider<FreeTrainingRecordController, FreeTrainingRecordState>(FreeTrainingRecordController.new);
final freeTrainingRecordStorageProvider =
    Provider<FreeTrainingRecordStorage>((ref) => FreeTrainingRecordStorage());
