import 'package:flutter/material.dart';

import 'free_training_panel_widgets.dart';

class FreeTrainingDataPanel extends StatelessWidget {
  const FreeTrainingDataPanel({
    required this.totalSeconds,
    required this.controlMaxValue,
    required this.longestControlTimeSeconds,
    required this.currentWindowMeanValue,
    required this.currentWindowDeltaValue,
    required this.deltaMaxValue,
    required this.deltaMinValue,
    required this.isDeviceConnected,
    required this.isPaused,
    required this.onReset,
    required this.onTogglePause,
    this.width,
    super.key,
  });

  final double totalSeconds;
  final double? controlMaxValue;
  final double? longestControlTimeSeconds;
  final double? currentWindowMeanValue;
  final double? currentWindowDeltaValue;
  final double? deltaMaxValue;
  final double? deltaMinValue;
  final bool isDeviceConnected;
  final bool isPaused;
  final VoidCallback onReset;
  final VoidCallback onTogglePause;
  final double? width;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2D76F8);
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final safeHeight = mediaQuery.size.height - mediaQuery.padding.vertical;
    final maxPanelHeight = safeHeight > 0 ? safeHeight : mediaQuery.size.height;
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxPanelHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 24,
                child: Stack(
                  children: <Widget>[
                    const Align(
                      alignment: Alignment.center,
                      child: Text('实时面板', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => _showMetricHelp(context),
                        icon: const Icon(Icons.help_outline, size: 16, color: Color(0xFF6E6E6E)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: PanelGrid(
                    entries: <PanelEntry>[
                      PanelEntry('最大控制力量', _formatKgNullable(controlMaxValue)),
                      PanelEntry('最长连续控制', _formatSecondsNullable(longestControlTimeSeconds)),
                      PanelEntry('1s均值', _formatKgNullable(currentWindowMeanValue)),
                      PanelEntry('1s变化', _formatKgNullable(currentWindowDeltaValue)),
                      PanelEntry('1s最大增长', _formatKgNullable(deltaMaxValue)),
                      PanelEntry('1s最大下降', _formatKgNullable(deltaMinValue)),
                      PanelEntry('总时长', _formatSeconds(totalSeconds)),
                    ],
                    isSingleColumn: isLandscape,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor, width: 1.2),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('重置', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              if (!isDeviceConnected) ...<Widget>[
                const Text('请连接设备', style: TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 4),
              ],
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  onPressed: isDeviceConnected ? onTogglePause : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDeviceConnected ? primaryColor : const Color(0xFFBDBDBD),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    isPaused ? '开始' : '暂停',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (isLandscape) {
      return IntrinsicWidth(child: content);
    }
    return SizedBox(width: width ?? 160, child: content);
  }

  String _formatKgNullable(double? value) => value == null ? '--' : '${value.toStringAsFixed(1)} KG';

  String _formatSeconds(double value) => '${value.toStringAsFixed(1)} 秒';

  String _formatSecondsNullable(double? value) => value == null ? '--' : '${value.toStringAsFixed(1)} 秒';
  Future<void> _showMetricHelp(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('指标说明'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FreeTrainingHelpItem(label: '最大控制力量', description: '达到力量峰值 95% 以上区间的中位数。'),
                FreeTrainingHelpItem(label: '最长连续控制', description: '力量连续不低于最大控制力量 95% 的最长时长。'),
                FreeTrainingHelpItem(label: '1s均值', description: '最近一个完整 1 秒窗口的平均力量。'),
                FreeTrainingHelpItem(label: '1s变化', description: '当前 1 秒均值减去上一个 1 秒均值。'),
                FreeTrainingHelpItem(label: '1s最大上升', description: '所有 1 秒变化中的最大上升值。'),
                FreeTrainingHelpItem(label: '1s最大下降', description: '所有 1 秒变化中的最大下降值。'),
                FreeTrainingHelpItem(label: '总时长', description: '本次自由训练累计时长。'),
              ],
            ),
          ),
          actions: <Widget>[TextButton(onPressed: Navigator.of(context).pop, child: const Text('知道了'))],
        );
      },
    );
  }
}
