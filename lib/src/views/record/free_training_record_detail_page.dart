import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/free_training_record.dart';
import '../../models/metric_definitions.dart';
import '../../providers/metric_visibility_provider.dart';
import 'record_formatters.dart';

class FreeTrainingRecordDetailPage extends ConsumerWidget {
  const FreeTrainingRecordDetailPage({required this.record, super.key});

  final FreeTrainingRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(metricVisibilityProvider);
    final detailDefinitions = freeSummaryMetricDefinitions
        .where((definition) => visibility.freeVisibility(definition.metric).showInDetail)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('自由训练记录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(record.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            formatRecordDateTime(record.startedAt),
            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E)),
          ),
          const SizedBox(height: 16),
          for (final definition in detailDefinitions) ...<Widget>[
            _detailRow(definition.label, _metricValue(definition.metric)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _metricValue(FreeSummaryMetric metric) {
    switch (metric) {
      case FreeSummaryMetric.totalDuration:
        return _formatSeconds(record.totalSeconds);
      case FreeSummaryMetric.controlMax:
        return _formatKg(record.controlMaxValue);
      case FreeSummaryMetric.longestControl:
        return _formatSeconds(record.longestControlTimeSeconds);
      case FreeSummaryMetric.windowMean:
        return _formatKg(record.currentWindowMeanValue);
      case FreeSummaryMetric.windowDelta:
        return _formatKg(record.currentWindowDeltaValue);
      case FreeSummaryMetric.deltaMax:
        return _formatKg(record.deltaMaxValue);
      case FreeSummaryMetric.deltaMin:
        return _formatKg(record.deltaMinValue);
    }
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

String _formatKg(double? value) {
  if (value == null || value.isNaN || value.isInfinite) {
    return 'N/A';
  }
  return '${value.toStringAsFixed(1)}kg';
}

String _formatSeconds(double? value) {
  if (value == null || value.isNaN || value.isInfinite) {
    return 'N/A';
  }
  return '${value.toStringAsFixed(1)}s';
}
