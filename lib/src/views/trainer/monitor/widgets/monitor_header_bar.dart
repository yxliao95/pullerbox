import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'measure_size.dart';
import 'monitor_exit_button.dart';
import 'monitor_toolbar.dart';

class MonitorHeaderBar extends StatelessWidget {
  const MonitorHeaderBar({
    required this.titleText,
    required this.isSoundOn,
    required this.isPaused,
    required this.toolbarHorizontalWidth,
    required this.estimatedToolbarWidth,
    required this.exitButtonHeight,
    required this.onExitSizeChange,
    required this.onToolbarSizeChange,
    required this.onExit,
    required this.onToggleSound,
    required this.onPrevious,
    required this.onTogglePause,
    required this.onNext,
    super.key,
  });

  final String titleText;
  final bool isSoundOn;
  final bool isPaused;
  final double toolbarHorizontalWidth;
  final double estimatedToolbarWidth;
  final double exitButtonHeight;
  final ValueChanged<Size> onExitSizeChange;
  final ValueChanged<Size> onToolbarSizeChange;
  final VoidCallback onExit;
  final VoidCallback onToggleSound;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const exitButtonWidth = 36.0;
          const minTitleGap = 8.0;
          final textScaler = MediaQuery.textScalerOf(context);
          final titlePainter = TextPainter(
            text: TextSpan(
              text: titleText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout();
          final resolvedToolbarWidth = toolbarHorizontalWidth > 0 ? toolbarHorizontalWidth : estimatedToolbarWidth;
          final maxReserved = math.max(exitButtonWidth, resolvedToolbarWidth);
          final availableCenterWidth = (constraints.maxWidth - 2 * maxReserved - minTitleGap * 2).clamp(
            0.0,
            constraints.maxWidth,
          );
          final isToolbarVertical = titlePainter.width > availableCenterWidth;
          final resolvedExitHeight = exitButtonHeight > 0 ? exitButtonHeight : exitButtonWidth;
          return Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: MeasureSize(
                  onChange: onExitSizeChange,
                  child: MonitorExitButton(onPressed: onExit),
                ),
              ),
              Center(
                child: SizedBox(
                  height: resolvedExitHeight,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      titleText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: isToolbarVertical
                    ? MonitorToolbar(
                        isSoundOn: isSoundOn,
                        isPaused: isPaused,
                        isVertical: true,
                        onToggleSound: onToggleSound,
                        onPrevious: onPrevious,
                        onTogglePause: onTogglePause,
                        onNext: onNext,
                      )
                    : MeasureSize(
                        onChange: onToolbarSizeChange,
                        child: MonitorToolbar(
                          isSoundOn: isSoundOn,
                          isPaused: isPaused,
                          isVertical: false,
                          onToggleSound: onToggleSound,
                          onPrevious: onPrevious,
                          onTogglePause: onTogglePause,
                          onNext: onNext,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
