import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/metric_definitions.dart';
import '../../models/training_record.dart';
import '../../providers/metric_visibility_provider.dart';
import 'record_formatters.dart';

class TrainingRecordDetailPage extends ConsumerWidget {
  const TrainingRecordDetailPage({required this.record, super.key});

  final TrainingRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(metricVisibilityProvider);
    final detailDefinitions = timedSummaryMetricDefinitions
        .where((definition) => visibility.timedVisibility(definition.metric).showInDetail)
        .toList();
    final guideMetricDefinitions = <MetricGuideDefinition>[
      for (final definition in detailDefinitions)
        MetricGuideDefinition(label: definition.label, description: definition.description),
    ];
    final guideDefinitions = timedGuideSupplementDefinitions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练详情'),
        actions: <Widget>[
          if (guideDefinitions.isNotEmpty || guideMetricDefinitions.isNotEmpty)
            IconButton(
              tooltip: '指标说明',
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showMetricGuide(
                context,
                guideDefinitions: guideDefinitions,
                guideMetricDefinitions: guideMetricDefinitions,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Text(record.planName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(formatRecordDateTime(record.startedAt), style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
          const SizedBox(height: 16),
          _detailRow('锻炼 / 休息 / 循环', '${record.workSeconds} / ${record.restSeconds} / ${record.cycles}'),
          const SizedBox(height: 8),
          _detailRow('总时间', formatRecordDuration(record.totalSeconds)),
          if (detailDefinitions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const Text('统计数据', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final definition in detailDefinitions) ...<Widget>[
              _detailRow(definition.label, _metricValue(definition.metric)),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 16),
          const Text('原始数据', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._buildGroupedRows(),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedRows() {
    if (record.groupedSamples.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('N/A', style: TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
        ),
      ];
    }
    return record.groupedSamples
        .map(
          (group) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('第 ${group.cycle} 组', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...group.samples.map(
                (sample) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _detailRow('${sample.time.toStringAsFixed(1)}s', '${sample.value.toStringAsFixed(1)}kg'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        )
        .toList();
  }

  String _formatWeight(double value) {
    if (record.groupedSamples.isEmpty || value.isNaN || value.isInfinite) {
      return 'N/A';
    }
    return '${value.toStringAsFixed(1)}kg';
  }

  String _formatCount(int value) {
    if (record.groupedSamples.isEmpty) {
      return 'N/A';
    }
    return value.toString();
  }

  String _formatFatigue(TrainingStatistics statistics) {
    if (record.groupedSamples.isEmpty) {
      return 'N/A';
    }
    if (statistics.fatigueStartCycle <= 0) {
      return '未触发';
    }
    return '第${statistics.fatigueStartCycle}轮 / ${statistics.fatigueStartTime.toStringAsFixed(1)}s';
  }

  String _formatMinControl(TrainingStatistics statistics) {
    if (record.groupedSamples.isEmpty) {
      return 'N/A';
    }
    if (statistics.fatigueStartCycle <= 0) {
      return '未触发';
    }
    if (statistics.minControlStrengthMissing) {
      return '缺失';
    }
    return _formatWeight(statistics.minControlStrength);
  }

  String _formatPercent(double value) {
    if (record.groupedSamples.isEmpty || value.isNaN || value.isInfinite) {
      return 'N/A';
    }
    if (record.statistics.fatigueStartCycle <= 0) {
      return 'N/A';
    }
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String _metricValue(TimedSummaryMetric metric) {
    switch (metric) {
      case TimedSummaryMetric.maxStrength:
        return _formatWeight(record.statistics.maxStrengthSession);
      case TimedSummaryMetric.maxControlStrength:
        return _formatWeight(record.statistics.maxControlStrengthSession);
      case TimedSummaryMetric.controlCycles:
        return _formatCount(record.statistics.controlCycles);
      case TimedSummaryMetric.fatigueSignal:
        return _formatFatigue(record.statistics);
      case TimedSummaryMetric.minControlStrength:
        return _formatMinControl(record.statistics);
      case TimedSummaryMetric.dropMean:
        return _formatPercent(record.statistics.dropMean);
      case TimedSummaryMetric.dropMax:
        return _formatPercent(record.statistics.dropMax);
      case TimedSummaryMetric.dropStd:
        return _formatPercent(record.statistics.dropStd);
    }
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

void _showMetricGuide(
  BuildContext context, {
  required List<MetricGuideDefinition> guideDefinitions,
  required List<MetricGuideDefinition> guideMetricDefinitions,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final hasDefinitions = guideDefinitions.isNotEmpty;
      final hasMetrics = guideMetricDefinitions.isNotEmpty;
      final showMetricsTitle = hasDefinitions && hasMetrics;
      return AlertDialog(
        title: const Text('指标说明'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (hasDefinitions) ...<Widget>[
                const _MetricGuideSectionTitle(title: '定义'),
                const SizedBox(height: 8),
                for (final definition in guideDefinitions)
                  _MetricGuideItem(label: definition.label, description: definition.description),
              ],
              if (hasDefinitions && hasMetrics) const SizedBox(height: 6),
              if (hasMetrics) ...<Widget>[
                if (showMetricsTitle) ...<Widget>[
                  const _MetricGuideSectionTitle(title: '指标'),
                  const SizedBox(height: 8),
                ],
                for (final definition in guideMetricDefinitions)
                  _MetricGuideItem(label: definition.label, description: definition.description),
              ],
            ],
          ),
        ),
        actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('知道了'))],
      );
    },
  );
}

class _MetricGuideItem extends StatelessWidget {
  const _MetricGuideItem({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        ],
      ),
    );
  }
}

class _MetricGuideSectionTitle extends StatelessWidget {
  const _MetricGuideSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blueAccent),
    );
  }
}
