class FreeTrainingRecord {
  const FreeTrainingRecord({
    required this.id,
    required this.title,
    required this.totalSeconds,
    required this.startedAt,
    required this.controlMaxValue,
    required this.longestControlTimeSeconds,
    required this.currentWindowMeanValue,
    required this.currentWindowDeltaValue,
    required this.deltaMaxValue,
    required this.deltaMinValue,
  });

  final String id;
  final String title;
  final double totalSeconds;
  final DateTime startedAt;
  final double? controlMaxValue;
  final double? longestControlTimeSeconds;
  final double? currentWindowMeanValue;
  final double? currentWindowDeltaValue;
  final double? deltaMaxValue;
  final double? deltaMinValue;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'totalSeconds': totalSeconds,
      'startedAt': startedAt.toIso8601String(),
      'controlMaxValue': controlMaxValue,
      'longestControlTimeSeconds': longestControlTimeSeconds,
      'currentWindowMeanValue': currentWindowMeanValue,
      'currentWindowDeltaValue': currentWindowDeltaValue,
      'deltaMaxValue': deltaMaxValue,
      'deltaMinValue': deltaMinValue,
    };
  }

  factory FreeTrainingRecord.fromJson(Map<String, dynamic> json) {
    return FreeTrainingRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '自由训练',
      totalSeconds: (json['totalSeconds'] as num?)?.toDouble() ?? 0.0,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
      controlMaxValue: (json['controlMaxValue'] as num?)?.toDouble(),
      longestControlTimeSeconds: (json['longestControlTimeSeconds'] as num?)?.toDouble(),
      currentWindowMeanValue: (json['currentWindowMeanValue'] as num?)?.toDouble(),
      currentWindowDeltaValue: (json['currentWindowDeltaValue'] as num?)?.toDouble(),
      deltaMaxValue: (json['deltaMaxValue'] as num?)?.toDouble(),
      deltaMinValue: (json['deltaMinValue'] as num?)?.toDouble(),
    );
  }
}

class FreeTrainingRecordSnapshot {
  const FreeTrainingRecordSnapshot({required this.records});

  final List<FreeTrainingRecord> records;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'records': records.map((record) => record.toJson()).toList(),
    };
  }

  factory FreeTrainingRecordSnapshot.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List? ?? <dynamic>[];
    final records = rawRecords
        .whereType<Map>()
        .map((record) => FreeTrainingRecord.fromJson(Map<String, dynamic>.from(record)))
        .toList();
    return FreeTrainingRecordSnapshot(records: records);
  }
}
