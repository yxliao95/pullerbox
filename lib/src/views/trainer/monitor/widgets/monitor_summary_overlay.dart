import 'package:flutter/material.dart';

import '../../../../models/training_record.dart';
import '../../../../models/training_summary.dart';
import 'measure_size.dart';

class MonitorSummaryOverlay extends StatefulWidget {
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
  State<MonitorSummaryOverlay> createState() => _MonitorSummaryOverlayState();
}

class _MonitorSummaryOverlayState extends State<MonitorSummaryOverlay> {
  double _exitButtonHeight = 0.0;

  @override
  Widget build(BuildContext context) {
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
                  if (widget.showStatistics && widget.summary.hasStatistics) ...<Widget>[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 36,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: _buildStatisticsMetrics(widget.summary.statistics),
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

  List<Widget> _buildStatisticsMetrics(TrainingStatistics statistics) {
    final hasFatigue = statistics.fatigueStartCycle > 0;
    final fatigueLabel = hasFatigue
        ? '第${statistics.fatigueStartCycle}轮 / ${statistics.fatigueStartTime.toStringAsFixed(1)}s'
        : '未触发';
    final minControlLabel = hasFatigue
        ? (statistics.minControlStrengthMissing ? '缺失' : _formatWeight(statistics.minControlStrength))
        : '未触发';
    return <Widget>[
      _SummaryMetric(label: '最大力量', value: _formatWeight(statistics.maxStrengthSession)),
      _SummaryMetric(label: '最大控制力量', value: _formatWeight(statistics.maxControlStrengthSession)),
      _SummaryMetric(label: '控制循环数', value: statistics.controlCycles.toString()),
      _SummaryMetric(label: '力竭信号', value: fatigueLabel),
      _SummaryMetric(label: '最低控制力量', value: minControlLabel),
      _SummaryMetric(label: '降幅均值', value: _formatPercent(statistics.dropMean, hasFatigue)),
      _SummaryMetric(label: '降幅最大', value: _formatPercent(statistics.dropMax, hasFatigue)),
      _SummaryMetric(label: '降幅标准差', value: _formatPercent(statistics.dropStd, hasFatigue)),
    ];
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
