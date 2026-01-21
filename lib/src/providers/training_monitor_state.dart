import '../models/chart_sample.dart';
import '../models/training_plan.dart';
import '../models/training_summary.dart';

class TrainingMonitorConfig {
  const TrainingMonitorConfig({
    required this.plan,
    required this.isDeviceConnected,
    required this.isFreeTraining,
  });

  final TrainingPlanState plan;
  final bool isDeviceConnected;
  final bool isFreeTraining;
}

class TrainingMonitorState {
  const TrainingMonitorState({
    required this.isFreeTraining,
    required this.isPreparing,
    required this.isWorking,
    required this.isPaused,
    required this.isFinishPending,
    required this.isSummaryVisible,
    required this.currentCycle,
    required this.elapsedInPhase,
    required this.currentValue,
    required this.chartMaxValue,
    required this.chartMaxLocked,
    required this.chartMaxReachTime,
    required this.samples,
    required this.summary,
    required this.freeTrainingElapsedSeconds,
    required this.freeTrainingTitle,
    required this.freeTrainingControlMaxValue,
    required this.freeTrainingLongestControlTimeSeconds,
    required this.freeTrainingCurrentWindowMeanValue,
    required this.freeTrainingCurrentWindowDeltaValue,
    required this.freeTrainingDeltaMaxValue,
    required this.freeTrainingDeltaMinValue,
  });

  final bool isFreeTraining;
  final bool isPreparing;
  final bool isWorking;
  final bool isPaused;
  final bool isFinishPending;
  final bool isSummaryVisible;
  final int currentCycle;
  final double elapsedInPhase;
  final double currentValue;
  final double chartMaxValue;
  final bool chartMaxLocked;
  final double chartMaxReachTime;
  final List<ChartSample> samples;
  final TrainingSummary? summary;
  final double freeTrainingElapsedSeconds;
  final String freeTrainingTitle;
  final double? freeTrainingControlMaxValue;
  final double? freeTrainingLongestControlTimeSeconds;
  final double? freeTrainingCurrentWindowMeanValue;
  final double? freeTrainingCurrentWindowDeltaValue;
  final double? freeTrainingDeltaMaxValue;
  final double? freeTrainingDeltaMinValue;

  TrainingMonitorState copyWith({
    bool? isPreparing,
    bool? isWorking,
    bool? isPaused,
    bool? isFinishPending,
    bool? isSummaryVisible,
    int? currentCycle,
    double? elapsedInPhase,
    double? currentValue,
    double? chartMaxValue,
    bool? chartMaxLocked,
    double? chartMaxReachTime,
    List<ChartSample>? samples,
    TrainingSummary? summary,
    double? freeTrainingElapsedSeconds,
    String? freeTrainingTitle,
    double? freeTrainingControlMaxValue,
    double? freeTrainingLongestControlTimeSeconds,
    double? freeTrainingCurrentWindowMeanValue,
    double? freeTrainingCurrentWindowDeltaValue,
    double? freeTrainingDeltaMaxValue,
    double? freeTrainingDeltaMinValue,
  }) {
    return TrainingMonitorState(
      isFreeTraining: isFreeTraining,
      isPreparing: isPreparing ?? this.isPreparing,
      isWorking: isWorking ?? this.isWorking,
      isPaused: isPaused ?? this.isPaused,
      isFinishPending: isFinishPending ?? this.isFinishPending,
      isSummaryVisible: isSummaryVisible ?? this.isSummaryVisible,
      currentCycle: currentCycle ?? this.currentCycle,
      elapsedInPhase: elapsedInPhase ?? this.elapsedInPhase,
      currentValue: currentValue ?? this.currentValue,
      chartMaxValue: chartMaxValue ?? this.chartMaxValue,
      chartMaxLocked: chartMaxLocked ?? this.chartMaxLocked,
      chartMaxReachTime: chartMaxReachTime ?? this.chartMaxReachTime,
      samples: samples ?? this.samples,
      summary: summary ?? this.summary,
      freeTrainingElapsedSeconds: freeTrainingElapsedSeconds ?? this.freeTrainingElapsedSeconds,
      freeTrainingTitle: freeTrainingTitle ?? this.freeTrainingTitle,
      freeTrainingControlMaxValue: freeTrainingControlMaxValue ?? this.freeTrainingControlMaxValue,
      freeTrainingLongestControlTimeSeconds:
          freeTrainingLongestControlTimeSeconds ?? this.freeTrainingLongestControlTimeSeconds,
      freeTrainingCurrentWindowMeanValue: freeTrainingCurrentWindowMeanValue ?? this.freeTrainingCurrentWindowMeanValue,
      freeTrainingCurrentWindowDeltaValue:
          freeTrainingCurrentWindowDeltaValue ?? this.freeTrainingCurrentWindowDeltaValue,
      freeTrainingDeltaMaxValue: freeTrainingDeltaMaxValue ?? this.freeTrainingDeltaMaxValue,
      freeTrainingDeltaMinValue: freeTrainingDeltaMinValue ?? this.freeTrainingDeltaMinValue,
    );
  }
}
