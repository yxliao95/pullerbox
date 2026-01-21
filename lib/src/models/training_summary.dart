import 'training_record.dart';

class TrainingSummary {
  const TrainingSummary({
    required this.planName,
    required this.workSeconds,
    required this.restSeconds,
    required this.cycles,
    required this.totalSeconds,
    required this.statistics,
    required this.hasStatistics,
  });

  final String planName;
  final int workSeconds;
  final int restSeconds;
  final int cycles;
  final int totalSeconds;
  final TrainingStatistics statistics;
  final bool hasStatistics;
}
