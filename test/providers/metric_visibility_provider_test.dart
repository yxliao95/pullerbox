import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pullerbox/src/models/metric_definitions.dart';
import 'package:pullerbox/src/providers/metric_visibility_provider.dart';

void main() {
  test('MetricVisibilityProvider defaults to show in all pages', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(metricVisibilityProvider);
    for (final definition in timedSummaryMetricDefinitions) {
      final visibility = state.timedVisibility(definition.metric);
      expect(visibility.showInSummary, isTrue);
      expect(visibility.showInFilter, isTrue);
      expect(visibility.showInDetail, isTrue);
    }
    for (final definition in freeSummaryMetricDefinitions) {
      final visibility = state.freeVisibility(definition.metric);
      expect(visibility.showInSummary, isTrue);
      expect(visibility.showInFilter, isTrue);
      expect(visibility.showInDetail, isTrue);
    }
  });

  test('MetricVisibilityProvider updates metric visibility', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(metricVisibilityProvider.notifier);
    notifier.setTimedVisibility(
      TimedSummaryMetric.maxStrength,
      const MetricVisibility(showInSummary: false, showInFilter: true, showInDetail: false),
    );

    final updated = container.read(metricVisibilityProvider);
    final visibility = updated.timedVisibility(TimedSummaryMetric.maxStrength);
    expect(visibility.showInSummary, isFalse);
    expect(visibility.showInFilter, isTrue);
    expect(visibility.showInDetail, isFalse);
  });
}
