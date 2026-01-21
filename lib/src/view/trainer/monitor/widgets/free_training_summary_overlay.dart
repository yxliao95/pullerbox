import 'package:flutter/material.dart';

import 'measure_size.dart';

class FreeTrainingSummaryOverlay extends StatefulWidget {
  const FreeTrainingSummaryOverlay({
    required this.defaultTitle,
    required this.totalSeconds,
    required this.controlMaxValue,
    required this.longestControlTimeSeconds,
    required this.currentWindowMeanValue,
    required this.currentWindowDeltaValue,
    required this.deltaMaxValue,
    required this.deltaMinValue,
    required this.onExitWithoutSave,
    required this.onSaveAndExit,
    super.key,
  });

  final String defaultTitle;
  final double totalSeconds;
  final double? controlMaxValue;
  final double? longestControlTimeSeconds;
  final double? currentWindowMeanValue;
  final double? currentWindowDeltaValue;
  final double? deltaMaxValue;
  final double? deltaMinValue;
  final VoidCallback onExitWithoutSave;
  final ValueChanged<String> onSaveAndExit;

  @override
  State<FreeTrainingSummaryOverlay> createState() => _FreeTrainingSummaryOverlayState();
}

class _FreeTrainingSummaryOverlayState extends State<FreeTrainingSummaryOverlay> {
  static const _fallbackTitle = '自由训练';
  late final TextEditingController _titleController;
  double _exitButtonHeight = 0.0;

  @override
  void initState() {
    super.initState();
    final initialTitle = widget.defaultTitle.trim().isEmpty ? _fallbackTitle : widget.defaultTitle;
    _titleController = TextEditingController(text: initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

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
                SizedBox(
                  width: 260,
                  child: TextFormField(
                    controller: _titleController,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: '自定义标题', isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 36,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    _SummaryMetric(label: '最大控制力量', value: _formatKg(widget.controlMaxValue)),
                    _SummaryMetric(label: '最长连续控制', value: _formatSeconds(widget.longestControlTimeSeconds)),
                    _SummaryMetric(label: '1s均值', value: _formatKg(widget.currentWindowMeanValue)),
                    _SummaryMetric(label: '1s变化', value: _formatKg(widget.currentWindowDeltaValue)),
                    _SummaryMetric(label: '1s最大增长', value: _formatKg(widget.deltaMaxValue)),
                    _SummaryMetric(label: '1s最大下降', value: _formatKg(widget.deltaMinValue)),
                    _SummaryMetric(label: '总时长', value: _formatSeconds(widget.totalSeconds)),
                  ],
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
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
                              onPressed: () => widget.onSaveAndExit(_resolveTitle()),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _resolveTitle() {
    final trimmed = _titleController.text.trim();
    return trimmed.isEmpty ? _fallbackTitle : trimmed;
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
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
