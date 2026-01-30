import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/training_record.dart';
import '../providers/training_statistics_provider.dart';
import '../services/random_source.dart';
import '../services/training_record_seed_builder.dart';
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
      final seedRecords = _buildSeedRecords();
      if (seedRecords.isEmpty) {
        return;
      }
      state = state.copyWith(records: seedRecords);
      unawaited(_persistHistory());
      return;
    }
    if (state.records.isEmpty) {
      state = state.copyWith(records: snapshot.records);
      return;
    }
    final existingIds = state.records.map((record) => record.id).toSet();
    final merged = <TrainingRecord>[
      ...state.records,
      ...snapshot.records.where((record) => !existingIds.contains(record.id)),
    ];
    state = state.copyWith(records: merged);
  }

  Future<void> _persistHistory() async {
    final snapshot = TrainingRecordSnapshot(records: state.records);
    await ref.read(trainingRecordStorageProvider).saveHistory(snapshot);
  }

  List<TrainingRecord> _buildSeedRecords() {
    final builder = _buildSeedBuilder(seed: 202601);
    return builder.buildMonthlyPlanRecords(
      year: 2026,
      month: 1,
      daysToPick: 10,
      planNames: const <String>['左手 10mm', '右手 10mm'],
      workSeconds: 10,
      restSeconds: 3,
      cycles: 20,
    );
  }

  TrainingRecordSeedBuilder _buildSeedBuilder({required int seed}) {
    final calculator = ref.read(trainingStatisticsCalculatorProvider);
    return TrainingRecordSeedBuilder(
      calculator: calculator,
      randomSource: SeededRandomSource(seed: seed),
      sampleIntervalSeconds: 0.05,
      noiseStrength: 0.6,
      maxStrength: 28.0,
      pattern: FakeCurvePattern.linearRise,
    );
  }

  void addRecord(TrainingRecord record) {
    state = state.copyWith(records: <TrainingRecord>[record, ...state.records]);
    unawaited(_persistHistory());
  }

  void removeRecord(String recordId) {
    state = state.copyWith(
      records: state.records.where((record) => record.id != recordId).toList(),
    );
    unawaited(_persistHistory());
  }

  void clearAllRecords() {
    state = state.copyWith(records: const <TrainingRecord>[]);
    unawaited(_persistHistory());
  }

  void buildRecordsForDate(DateTime date) {
    final generatorSeed = date.millisecondsSinceEpoch & 0x7fffffff;
    final builder = _buildSeedBuilder(seed: generatorSeed);
    final records = builder.buildPlanRecordsForDate(
      date: date,
      planNames: const <String>['左手 10mm', '右手 10 mm'],
      workSeconds: 10,
      restSeconds: 3,
      cycles: 20,
    );
    if (records.isEmpty) {
      return;
    }
    state = state.copyWith(records: <TrainingRecord>[...records, ...state.records]);
    unawaited(_persistHistory());
  }
}

final trainingRecordProvider = NotifierProvider<TrainingRecordController, TrainingRecordState>(
  TrainingRecordController.new,
);
final trainingRecordStorageProvider = Provider<TrainingRecordStorage>((ref) => TrainingRecordStorage());
