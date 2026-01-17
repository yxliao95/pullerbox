import 'package:flutter/material.dart';

class MonitorProgressBar extends StatelessWidget {
  const MonitorProgressBar({required this.progress, required this.color, required this.label, super.key});

  final double progress;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: double.infinity,
      color: Colors.white,
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: ColoredBox(color: color),
            ),
          ),
          Center(
            child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
