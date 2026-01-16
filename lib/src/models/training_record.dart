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

class TrainingStatistics {
  const TrainingStatistics({
    required this.maxValue,
    required this.averageValue,
    required this.medianValue,
  });

  final double maxValue;
  final double averageValue;
  final double medianValue;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'maxValue': maxValue,
      'averageValue': averageValue,
      'medianValue': medianValue,
    };
  }

  factory TrainingStatistics.fromJson(Map<String, dynamic> json) {
    return TrainingStatistics(
      maxValue: (json['maxValue'] as num?)?.toDouble() ?? 0.0,
      averageValue: (json['averageValue'] as num?)?.toDouble() ?? 0.0,
      medianValue: (json['medianValue'] as num?)?.toDouble() ?? 0.0,
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
    required this.samples,
    required this.statistics,
  });

  final String id;
  final String planName;
  final int workSeconds;
  final int restSeconds;
  final int cycles;
  final int totalSeconds;
  final DateTime startedAt;
  final List<TrainingSample> samples;
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
      'samples': samples.map((sample) => sample.toJson()).toList(),
      'statistics': statistics.toJson(),
    };
  }

  factory TrainingRecord.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['samples'] as List? ?? <dynamic>[];
    final rawStatistics = json['statistics'] as Map? ?? <dynamic, dynamic>{};
    return TrainingRecord(
      id: json['id'] as String? ?? '',
      planName: json['planName'] as String? ?? '默认',
      workSeconds: (json['workSeconds'] as num?)?.toInt() ?? 0,
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 0,
      cycles: (json['cycles'] as num?)?.toInt() ?? 0,
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
      samples: rawSamples
          .whereType<Map>()
          .map((sample) => TrainingSample.fromJson(Map<String, dynamic>.from(sample)))
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
