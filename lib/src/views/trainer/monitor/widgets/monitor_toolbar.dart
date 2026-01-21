import 'package:flutter/material.dart';

class MonitorToolbar extends StatelessWidget {
  const MonitorToolbar({
    required this.isSoundOn,
    required this.isPaused,
    required this.isVertical,
    required this.onToggleSound,
    required this.onPrevious,
    required this.onTogglePause,
    required this.onNext,
    super.key,
  });

  final bool isSoundOn;
  final bool isPaused;
  final bool isVertical;
  final VoidCallback onToggleSound;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _CompactIconButton(
        onPressed: onToggleSound,
        icon: Icon(isSoundOn ? Icons.volume_up : Icons.volume_off, size: 20),
      ),
      _CompactIconButton(onPressed: onPrevious, icon: const Icon(Icons.skip_previous, size: 20)),
      _CompactIconButton(
        onPressed: onTogglePause,
        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 20),
      ),
      _CompactIconButton(onPressed: onNext, icon: const Icon(Icons.skip_next, size: 20)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFE6E6E6), borderRadius: BorderRadius.circular(20)),
      child: isVertical
          ? Column(mainAxisSize: MainAxisSize.min, children: children)
          : Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final Icon icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
    );
  }
}
