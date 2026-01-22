import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/metric_definitions.dart';

class MetricVisibilityState {
  const MetricVisibilityState({
    required this.timedSummary,
    required this.freeSummary,
  });

  final Map<TimedSummaryMetric, MetricVisibility> timedSummary;
  final Map<FreeSummaryMetric, MetricVisibility> freeSummary;

  factory MetricVisibilityState.defaults() {
    return MetricVisibilityState(
      timedSummary: <TimedSummaryMetric, MetricVisibility>{
        for (final definition in timedSummaryMetricDefinitions) definition.metric: definition.visibility,
      },
      freeSummary: <FreeSummaryMetric, MetricVisibility>{
        for (final definition in freeSummaryMetricDefinitions) definition.metric: definition.visibility,
      },
    );
  }

  MetricVisibility timedVisibility(TimedSummaryMetric metric) {
    return timedSummary[metric] ?? const MetricVisibility();
  }

  MetricVisibility freeVisibility(FreeSummaryMetric metric) {
    return freeSummary[metric] ?? const MetricVisibility();
  }

  MetricVisibilityState copyWith({
    Map<TimedSummaryMetric, MetricVisibility>? timedSummary,
    Map<FreeSummaryMetric, MetricVisibility>? freeSummary,
  }) {
    return MetricVisibilityState(
      timedSummary: timedSummary ?? this.timedSummary,
      freeSummary: freeSummary ?? this.freeSummary,
    );
  }
}

class MetricVisibilityController extends Notifier<MetricVisibilityState> {
  @override
  MetricVisibilityState build() {
    return MetricVisibilityState.defaults();
  }

  void setTimedVisibility(TimedSummaryMetric metric, MetricVisibility visibility) {
    state = state.copyWith(
      timedSummary: <TimedSummaryMetric, MetricVisibility>{
        ...state.timedSummary,
        metric: visibility,
      },
    );
  }

  void setFreeVisibility(FreeSummaryMetric metric, MetricVisibility visibility) {
    state = state.copyWith(
      freeSummary: <FreeSummaryMetric, MetricVisibility>{
        ...state.freeSummary,
        metric: visibility,
      },
    );
  }
}

final metricVisibilityProvider = NotifierProvider<MetricVisibilityController, MetricVisibilityState>(
  MetricVisibilityController.new,
);
