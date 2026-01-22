class TrainingSample {
  const TrainingSample({required this.time, required this.value});

  final double time;
  final double value;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'time': time,
      'value': value,
    };
  }

  factory TrainingSample.fromJson(Map<String, dynamic> json) {
    return TrainingSample(
      time: (json['time'] as num?)?.toDouble() ?? 0.0,
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TrainingSampleGroup {
  const TrainingSampleGroup({required this.cycle, required this.samples});

  final int cycle;
  final List<TrainingSample> samples;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cycle': cycle,
      'samples': samples.map((sample) => sample.toJson()).toList(),
    };
  }

  factory TrainingSampleGroup.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['samples'] as List? ?? <dynamic>[];
    return TrainingSampleGroup(
      cycle: (json['cycle'] as num?)?.toInt() ?? 1,
      samples: rawSamples
          .whereType<Map>()
          .map((sample) => TrainingSample.fromJson(Map<String, dynamic>.from(sample)))
          .toList(),
    );
  }
}

class TrainingCycleStatistics {
  const TrainingCycleStatistics({
    required this.cycle,
    required this.maxStrength,
    required this.controlStrength,
    required this.controlTime,
    required this.outTime,
    required this.averageStrength,
    required this.fallbackLevel,
    required this.fail,
    required this.startTime,
    this.lowTime,
  });

  final int cycle;
  final double maxStrength;
  final double controlStrength;
  final double controlTime;
  final double outTime;
  final double averageStrength;
  final int fallbackLevel;
  final bool fail;
  final double startTime;
  final double? lowTime;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cycle': cycle,
      'maxStrength': maxStrength,
      'controlStrength': controlStrength,
      'controlTime': controlTime,
      'outTime': outTime,
      'averageStrength': averageStrength,
      'fallbackLevel': fallbackLevel,
      'fail': fail,
      'startTime': startTime,
      'lowTime': lowTime,
    };
  }

  factory TrainingCycleStatistics.fromJson(Map<String, dynamic> json) {
    return TrainingCycleStatistics(
      cycle: (json['cycle'] as num?)?.toInt() ?? 1,
      maxStrength: (json['maxStrength'] as num?)?.toDouble() ?? 0.0,
      controlStrength: (json['controlStrength'] as num?)?.toDouble() ?? 0.0,
      controlTime: (json['controlTime'] as num?)?.toDouble() ?? 0.0,
      outTime: (json['outTime'] as num?)?.toDouble() ?? 0.0,
      averageStrength: (json['averageStrength'] as num?)?.toDouble() ?? 0.0,
      fallbackLevel: (json['fallbackLevel'] as num?)?.toInt() ?? -1,
      fail: json['fail'] as bool? ?? false,
      startTime: (json['startTime'] as num?)?.toDouble() ?? 0.0,
      lowTime: (json['lowTime'] as num?)?.toDouble(),
    );
  }
}

class TrainingStatistics {
  const TrainingStatistics({
    required this.maxStrengthSession,
    required this.maxControlStrengthSession,
    required this.controlCycles,
    required this.fatigueStartCycle,
    required this.fatigueStartTime,
    required this.fatigueStartTimestamp,
    required this.minControlStrength,
    required this.minControlStrengthMissing,
    required this.dropMean,
    required this.dropMax,
    required this.dropStd,
    required this.ruleVersion,
    required this.quantile,
    required this.thresholdRatio,
    required this.enterDurations,
    required this.controlToleranceSeconds,
    required this.fatigueThresholdRatio,
    required this.fatigueDurationSeconds,
    required this.stableWindowSeconds,
    required this.stableWindowCv,
    required this.cycleStatistics,
  });

  final double maxStrengthSession;
  final double maxControlStrengthSession;
  final int controlCycles;
  final int fatigueStartCycle;
  final double fatigueStartTime;
  final double fatigueStartTimestamp;
  final double minControlStrength;
  final bool minControlStrengthMissing;
  final double dropMean;
  final double dropMax;
  final double dropStd;
  final String ruleVersion;
  final double quantile;
  final double thresholdRatio;
  final List<double> enterDurations;
  final double controlToleranceSeconds;
  final double fatigueThresholdRatio;
  final double fatigueDurationSeconds;
  final double stableWindowSeconds;
  final double stableWindowCv;
  final List<TrainingCycleStatistics> cycleStatistics;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'maxStrengthSession': maxStrengthSession,
      'maxControlStrengthSession': maxControlStrengthSession,
      'controlCycles': controlCycles,
      'fatigueStartCycle': fatigueStartCycle,
      'fatigueStartTime': fatigueStartTime,
      'fatigueStartTimestamp': fatigueStartTimestamp,
      'minControlStrength': minControlStrength,
      'minControlStrengthMissing': minControlStrengthMissing,
      'dropMean': dropMean,
      'dropMax': dropMax,
      'dropStd': dropStd,
      'ruleVersion': ruleVersion,
      'quantile': quantile,
      'thresholdRatio': thresholdRatio,
      'enterDurations': enterDurations,
      'controlToleranceSeconds': controlToleranceSeconds,
      'fatigueThresholdRatio': fatigueThresholdRatio,
      'fatigueDurationSeconds': fatigueDurationSeconds,
      'stableWindowSeconds': stableWindowSeconds,
      'stableWindowCv': stableWindowCv,
      'cycleStatistics': cycleStatistics.map((stat) => stat.toJson()).toList(),
    };
  }

  factory TrainingStatistics.fromJson(Map<String, dynamic> json) {
    final rawCycles = json['cycleStatistics'] as List? ?? <dynamic>[];
    final legacyMax = (json['maxValue'] as num?)?.toDouble();
    final legacyAverage = (json['averageValue'] as num?)?.toDouble();
    final legacyMedian = (json['medianValue'] as num?)?.toDouble();
    return TrainingStatistics(
      maxStrengthSession: (json['maxStrengthSession'] as num?)?.toDouble() ?? legacyMax ?? 0.0,
      maxControlStrengthSession: (json['maxControlStrengthSession'] as num?)?.toDouble() ??
          legacyMedian ??
          legacyAverage ??
          0.0,
      controlCycles: (json['controlCycles'] as num?)?.toInt() ?? 0,
      fatigueStartCycle: (json['fatigueStartCycle'] as num?)?.toInt() ?? 0,
      fatigueStartTime: (json['fatigueStartTime'] as num?)?.toDouble() ?? 0.0,
      fatigueStartTimestamp: (json['fatigueStartTimestamp'] as num?)?.toDouble() ?? 0.0,
      minControlStrength: (json['minControlStrength'] as num?)?.toDouble() ?? 0.0,
      minControlStrengthMissing: json['minControlStrengthMissing'] as bool? ?? true,
      dropMean: (json['dropMean'] as num?)?.toDouble() ?? 0.0,
      dropMax: (json['dropMax'] as num?)?.toDouble() ?? 0.0,
      dropStd: (json['dropStd'] as num?)?.toDouble() ?? 0.0,
      ruleVersion: json['ruleVersion'] as String? ?? '',
      quantile: (json['quantile'] as num?)?.toDouble() ?? 0.99,
      thresholdRatio: (json['thresholdRatio'] as num?)?.toDouble() ?? 0.95,
      enterDurations: (json['enterDurations'] as List?)
              ?.whereType<num>()
              .map((value) => value.toDouble())
              .toList() ??
          <double>[0.30, 0.20, 0.10, 0.05],
      controlToleranceSeconds: (json['controlToleranceSeconds'] as num?)?.toDouble() ?? 0.5,
      fatigueThresholdRatio: (json['fatigueThresholdRatio'] as num?)?.toDouble() ?? 0.8,
      fatigueDurationSeconds: (json['fatigueDurationSeconds'] as num?)?.toDouble() ?? 1.0,
      stableWindowSeconds: (json['stableWindowSeconds'] as num?)?.toDouble() ?? 1.0,
      stableWindowCv: (json['stableWindowCv'] as num?)?.toDouble() ?? 0.05,
      cycleStatistics: rawCycles
          .whereType<Map>()
          .map((stat) => TrainingCycleStatistics.fromJson(Map<String, dynamic>.from(stat)))
          .toList(),
    );
  }
}

class TrainingRecord {
  const TrainingRecord({
    required this.id,
    required this.planName,
    required this.workSeconds,
    required this.restSeconds,
    required this.cycles,
    required this.totalSeconds,
    required this.startedAt,
    this.groupedSamples = const <TrainingSampleGroup>[],
    required this.statistics,
  });

  final String id;
  final String planName;
  final int workSeconds;
  final int restSeconds;
  final int cycles;
  final int totalSeconds;
  final DateTime startedAt;
  final List<TrainingSampleGroup> groupedSamples;
  final TrainingStatistics statistics;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'planName': planName,
      'workSeconds': workSeconds,
      'restSeconds': restSeconds,
      'cycles': cycles,
      'totalSeconds': totalSeconds,
      'startedAt': startedAt.toIso8601String(),
      'groupedSamples': groupedSamples.map((group) => group.toJson()).toList(),
      'statistics': statistics.toJson(),
    };
  }

  factory TrainingRecord.fromJson(Map<String, dynamic> json) {
    final rawGroupedSamples = json['groupedSamples'] as List? ?? <dynamic>[];
    final rawStatistics = json['statistics'] as Map? ?? <dynamic, dynamic>{};
    return TrainingRecord(
      id: json['id'] as String? ?? '',
      planName: json['planName'] as String? ?? '默认',
      workSeconds: (json['workSeconds'] as num?)?.toInt() ?? 0,
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 0,
      cycles: (json['cycles'] as num?)?.toInt() ?? 0,
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      groupedSamples: rawGroupedSamples
          .whereType<Map>()
          .map((group) => TrainingSampleGroup.fromJson(Map<String, dynamic>.from(group)))
          .toList(),
      statistics: TrainingStatistics.fromJson(Map<String, dynamic>.from(rawStatistics)),
    );
  }
}

class TrainingRecordSnapshot {
  const TrainingRecordSnapshot({required this.records});

  final List<TrainingRecord> records;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'records': records.map((record) => record.toJson()).toList(),
    };
  }

  factory TrainingRecordSnapshot.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List? ?? <dynamic>[];
    final records = rawRecords
        .whereType<Map>()
        .map((record) => TrainingRecord.fromJson(Map<String, dynamic>.from(record)))
        .toList();
    return TrainingRecordSnapshot(records: records);
  }
}
