import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/training_record.dart';
import '../services/training_record_storage.dart';

class TrainingRecordState {
  const TrainingRecordState({required this.records});

  final List<TrainingRecord> records;

  TrainingRecordState copyWith({List<TrainingRecord>? records}) {
    return TrainingRecordState(records: records ?? this.records);
  }
}

class TrainingRecordController extends Notifier<TrainingRecordState> {
  @override
  TrainingRecordState build() {
    final initialState = const TrainingRecordState(records: <TrainingRecord>[]);
    unawaited(_restoreHistory());
    return initialState;
  }

  Future<void> _restoreHistory() async {
    final snapshot = await ref.read(trainingRecordStorageProvider).loadHistory();
    if (snapshot == null) {
      return;
    }
    state = state.copyWith(records: snapshot.records);
  }

  Future<void> _persistHistory() async {
    final snapshot = TrainingRecordSnapshot(records: state.records);
    await ref.read(trainingRecordStorageProvider).saveHistory(snapshot);
  }

  void addRecord(TrainingRecord record) {
    state = state.copyWith(records: <TrainingRecord>[record, ...state.records]);
    unawaited(_persistHistory());
  }
}

final trainingRecordProvider = NotifierProvider<TrainingRecordController, TrainingRecordState>(
  TrainingRecordController.new,
);
final trainingRecordStorageProvider = Provider<TrainingRecordStorage>((ref) => TrainingRecordStorage());
