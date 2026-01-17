import 'package:flutter/material.dart';

import 'measure_size.dart';

class TrainingSummary {
  const TrainingSummary({
    required this.planName,
    required this.workSeconds,
    required this.restSeconds,
    required this.cycles,
    required this.totalSeconds,
    required this.maxValue,
    required this.averageValue,
    required this.medianValue,
  });

  final String planName;
  final int workSeconds;
  final int restSeconds;
  final int cycles;
  final int totalSeconds;
  final double maxValue;
  final double averageValue;
  final double medianValue;
}

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.summary.planName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
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
                    _SummaryMetric(
                      label: '总时间',
                      value: _formatDuration(widget.summary.totalSeconds),
                    ),
                  ],
                ),
                if (widget.showStatistics) ...<Widget>[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _SummaryMetric(label: '最大值', value: '${widget.summary.maxValue.toStringAsFixed(1)}kg'),
                      const SizedBox(width: 36),
                      _SummaryMetric(label: '平均值', value: '${widget.summary.averageValue.toStringAsFixed(1)}kg'),
                      const SizedBox(width: 36),
                      _SummaryMetric(label: '中位数', value: '${widget.summary.medianValue.toStringAsFixed(1)}kg'),
                    ],
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
                            child: const Text(
                              '直接退出',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
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
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString()}:${remaining.toString().padLeft(2, '0')}';
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
