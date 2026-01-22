import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/metric_definitions.dart';
import '../../../../models/training_record.dart';
import '../../../../models/training_summary.dart';
import '../../../../providers/metric_visibility_provider.dart';
import 'measure_size.dart';

class MonitorSummaryOverlay extends ConsumerStatefulWidget {
  const MonitorSummaryOverlay({
    required this.summary,
    required this.showStatistics,
    required this.onExitWithoutSave,
    required this.onSaveAndExit,
    super.key,
  });

  final TrainingSummary summary;
  final bool showStatistics;
  final VoidCallback onExitWithoutSave;
  final VoidCallback onSaveAndExit;

  @override
  ConsumerState<MonitorSummaryOverlay> createState() => _MonitorSummaryOverlayState();
}

class _MonitorSummaryOverlayState extends ConsumerState<MonitorSummaryOverlay> {
  double _exitButtonHeight = 0.0;

  @override
  Widget build(BuildContext context) {
    final visibility = ref.watch(metricVisibilityProvider);
    final summaryDefinitions = timedSummaryMetricDefinitions
        .where((definition) => visibility.timedVisibility(definition.metric).showInSummary)
        .toList();
    final showMetrics =
        widget.showStatistics && widget.summary.hasStatistics && summaryDefinitions.isNotEmpty;
    const defaultExitHeight = 36.0;
    const topPadding = 6.0;
    final resolvedExitHeight = _exitButtonHeight > 0 ? _exitButtonHeight : defaultExitHeight;
    return Container(
      color: const Color(0xFFF2F2F2),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, topPadding, 8, 0),
              child: MeasureSize(
                onChange: (size) {
                  if (size.height != _exitButtonHeight) {
                    setState(() {
                      _exitButtonHeight = size.height;
                    });
                  }
                },
                child: IconButton(
                  onPressed: widget.onExitWithoutSave,
                  icon: const Icon(Icons.close, color: Colors.black87),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ),
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            child: SizedBox(
              height: resolvedExitHeight,
              child: const Align(
                alignment: Alignment.center,
                child: Text(
                  '已完成',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      widget.summary.planName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _SummaryMetric(
                        label: '锻炼 / 休息 / 循环',
                        value:
                            '${widget.summary.workSeconds} / ${widget.summary.restSeconds} / ${widget.summary.cycles}',
                      ),
                      const SizedBox(width: 48),
                      _SummaryMetric(label: '总时间', value: _formatDuration(widget.summary.totalSeconds)),
                    ],
                  ),
                  if (showMetrics) ...<Widget>[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 36,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: _buildStatisticsMetrics(widget.summary.statistics, summaryDefinitions),
                    ),
                    const SizedBox(height: 28),
                  ] else
                    const SizedBox(height: 28),
                  SizedBox(
                    width: 360,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: widget.onExitWithoutSave,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2D76F8),
                                side: const BorderSide(color: Color(0xFF2D76F8)),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('直接退出', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: widget.onSaveAndExit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2D76F8),
                                shape: const StadiumBorder(),
                                elevation: 0,
                              ),
                              child: const Text(
                                '保存并退出',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString()}:${remaining.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildStatisticsMetrics(
    TrainingStatistics statistics,
    List<MetricDefinition<TimedSummaryMetric>> definitions,
  ) {
    final hasFatigue = statistics.fatigueStartCycle > 0;
    final fatigueLabel = hasFatigue
        ? '第${statistics.fatigueStartCycle}轮 / ${statistics.fatigueStartTime.toStringAsFixed(1)}s'
        : '未触发';
    final minControlLabel = hasFatigue
        ? (statistics.minControlStrengthMissing ? '缺失' : _formatWeight(statistics.minControlStrength))
        : '未触发';
    return <Widget>[
      for (final definition in definitions)
        _SummaryMetric(
          label: definition.label,
          value: _summaryValue(statistics, definition.metric, fatigueLabel, minControlLabel, hasFatigue),
        ),
    ];
  }

  String _summaryValue(
    TrainingStatistics statistics,
    TimedSummaryMetric metric,
    String fatigueLabel,
    String minControlLabel,
    bool hasFatigue,
  ) {
    switch (metric) {
      case TimedSummaryMetric.maxStrength:
        return _formatWeight(statistics.maxStrengthSession);
      case TimedSummaryMetric.maxControlStrength:
        return _formatWeight(statistics.maxControlStrengthSession);
      case TimedSummaryMetric.controlCycles:
        return statistics.controlCycles.toString();
      case TimedSummaryMetric.fatigueSignal:
        return fatigueLabel;
      case TimedSummaryMetric.minControlStrength:
        return minControlLabel;
      case TimedSummaryMetric.dropMean:
        return _formatPercent(statistics.dropMean, hasFatigue);
      case TimedSummaryMetric.dropMax:
        return _formatPercent(statistics.dropMax, hasFatigue);
      case TimedSummaryMetric.dropStd:
        return _formatPercent(statistics.dropStd, hasFatigue);
    }
  }

  String _formatWeight(double value) {
    if (value.isNaN || value.isInfinite) {
      return 'N/A';
    }
    return '${value.toStringAsFixed(1)}kg';
  }

  String _formatPercent(double value, bool isAvailable) {
    if (!isAvailable || value.isNaN || value.isInfinite) {
      return 'N/A';
    }
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF8E8E8E)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ],
    );
  }
}
