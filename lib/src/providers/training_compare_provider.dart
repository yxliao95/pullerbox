import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/metric_definitions.dart';
import '../models/training_record.dart';
import 'system_providers.dart';
import 'training_record_provider.dart';

class TrainingCompareFilterState {
  const TrainingCompareFilterState({
    required this.startDate,
    required this.endDate,
    required this.metric,
    this.leftPlanName,
    this.rightPlanName,
  });

  final DateTime startDate;
  final DateTime endDate;
  final TimedSummaryMetric metric;
  final String? leftPlanName;
  final String? rightPlanName;

  TrainingCompareFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    TimedSummaryMetric? metric,
    String? leftPlanName,
    String? rightPlanName,
  }) {
    return TrainingCompareFilterState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      metric: metric ?? this.metric,
      leftPlanName: leftPlanName ?? this.leftPlanName,
      rightPlanName: rightPlanName ?? this.rightPlanName,
    );
  }
}

class TrainingCompareFilterController extends Notifier<TrainingCompareFilterState> {
  @override
  TrainingCompareFilterState build() {
    final now = ref.read(clockProvider).now();
    final endDate = _dateOnly(now);
    final startDate = _subtractMonths(endDate, 3);
    return TrainingCompareFilterState(
      startDate: startDate,
      endDate: endDate,
      metric: TimedSummaryMetric.maxStrength,
    );
  }

  void resetRecentMonths() {
    final now = ref.read(clockProvider).now();
    final endDate = _dateOnly(now);
    final startDate = _subtractMonths(endDate, 3);
    state = state.copyWith(startDate: startDate, endDate: endDate);
  }

  void setStartDate(DateTime date) {
    final startDate = _dateOnly(date);
    final endDate = state.endDate.isBefore(startDate) ? startDate : state.endDate;
    state = state.copyWith(startDate: startDate, endDate: endDate);
  }

  void setEndDate(DateTime date) {
    final endDate = _dateOnly(date);
    final startDate = state.startDate.isAfter(endDate) ? endDate : state.startDate;
    state = state.copyWith(startDate: startDate, endDate: endDate);
  }

  void setMetric(TimedSummaryMetric metric) {
    state = state.copyWith(metric: metric);
  }

  void setLeftPlanName(String? planName) {
    state = state.copyWith(leftPlanName: planName);
  }

  void setRightPlanName(String? planName) {
    state = state.copyWith(rightPlanName: planName);
  }
}

class TrainingCompareMetricStats {
  const TrainingCompareMetricStats({
    required this.maxValue,
    required this.minValue,
    required this.lastValue,
    required this.lastDate,
    required this.recordCount,
    required this.values,
  });

  const TrainingCompareMetricStats.empty()
      : maxValue = null,
        minValue = null,
        lastValue = null,
        lastDate = null,
        recordCount = 0,
        values = const <double>[];

  final double? maxValue;
  final double? minValue;
  final double? lastValue;
  final DateTime? lastDate;
  final int recordCount;
  final List<double> values;
}

class TrainingCompareResult {
  const TrainingCompareResult({
    required this.filter,
    required this.left,
    required this.right,
    required this.globalMaxValue,
    required this.globalMinValue,
    required this.availablePlanNames,
  });

  final TrainingCompareFilterState filter;
  final TrainingCompareMetricStats left;
  final TrainingCompareMetricStats right;
  final double globalMaxValue;
  final double globalMinValue;
  final List<String> availablePlanNames;
}

final trainingCompareFilterProvider =
    NotifierProvider<TrainingCompareFilterController, TrainingCompareFilterState>(
  TrainingCompareFilterController.new,
);

final trainingCompareResultProvider = Provider<TrainingCompareResult>((ref) {
  final filter = ref.watch(trainingCompareFilterProvider);
  final records = ref.watch(trainingRecordProvider).records;
  final availablePlanNames = records.map((record) => record.planName).toSet().toList()..sort();
  final left = _buildMetricStats(filter.leftPlanName, filter, records);
  final right = _buildMetricStats(filter.rightPlanName, filter, records);
  final globalMaxValue = math.max(left.maxValue ?? 0, right.maxValue ?? 0);
  final globalMinValue = _resolveGlobalMin(left.minValue, right.minValue);
  return TrainingCompareResult(
    filter: filter,
    left: left,
    right: right,
    globalMaxValue: globalMaxValue,
    globalMinValue: globalMinValue,
    availablePlanNames: availablePlanNames,
  );
});

double _resolveGlobalMin(double? leftMin, double? rightMin) {
  if (leftMin == null && rightMin == null) {
    return 0;
  }
  if (leftMin == null) {
    return rightMin!;
  }
  if (rightMin == null) {
    return leftMin;
  }
  return math.min(leftMin, rightMin);
}

TrainingCompareMetricStats _buildMetricStats(
  String? planName,
  TrainingCompareFilterState filter,
  List<TrainingRecord> records,
) {
  if (planName == null) {
    return const TrainingCompareMetricStats.empty();
  }
  final matched = records
      .where((record) =>
          record.planName == planName && _isWithinRange(record.startedAt, filter.startDate, filter.endDate))
      .toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  if (matched.isEmpty) {
    return const TrainingCompareMetricStats.empty();
  }

  final values = <double>[];
  for (final record in matched) {
    final value = _metricValue(record, filter.metric);
    if (value != null) {
      values.add(value);
    }
  }
  final lastRecord = matched.last;
  final lastValue = _metricValue(lastRecord, filter.metric);
  return TrainingCompareMetricStats(
    maxValue: values.isEmpty ? null : values.reduce(math.max),
    minValue: values.isEmpty ? null : values.reduce(math.min),
    lastValue: lastValue,
    lastDate: lastRecord.startedAt,
    recordCount: matched.length,
    values: values,
  );
}

bool _isWithinRange(DateTime date, DateTime startDate, DateTime endDate) {
  final target = _dateOnly(date);
  return !target.isBefore(startDate) && !target.isAfter(endDate);
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _subtractMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month - months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  final clampedDay = math.min(date.day, lastDay);
  return DateTime(target.year, target.month, clampedDay);
}

double? _metricValue(TrainingRecord record, TimedSummaryMetric metric) {
  if (record.groupedSamples.isEmpty) {
    return null;
  }
  final statistics = record.statistics;
  switch (metric) {
    case TimedSummaryMetric.maxStrength:
      return _sanitizeValue(statistics.maxStrengthSession);
    case TimedSummaryMetric.maxControlStrength:
      return _sanitizeValue(statistics.maxControlStrengthSession);
    case TimedSummaryMetric.controlCycles:
      return _sanitizeValue(statistics.controlCycles.toDouble());
    case TimedSummaryMetric.fatigueSignal:
      return null;
    case TimedSummaryMetric.minControlStrength:
      if (statistics.fatigueStartCycle <= 0 || statistics.minControlStrengthMissing) {
        return null;
      } else {
        return _sanitizeValue(statistics.minControlStrength);
      }
    case TimedSummaryMetric.dropMean:
      if (statistics.fatigueStartCycle <= 0) {
        return null;
      } else {
        return _sanitizeValue(statistics.dropMean);
      }
    case TimedSummaryMetric.dropMax:
      if (statistics.fatigueStartCycle <= 0) {
        return null;
      } else {
        return _sanitizeValue(statistics.dropMax);
      }
    case TimedSummaryMetric.dropStd:
      if (statistics.fatigueStartCycle <= 0) {
        return null;
      } else {
        return _sanitizeValue(statistics.dropStd);
      }
  }
}

double? _sanitizeValue(double? value) {
  if (value == null || value.isNaN || value.isInfinite) {
    return null;
  }
  return value;
}
