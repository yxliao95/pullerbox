import 'package:flutter/material.dart';

class MonitorProgressBar extends StatelessWidget {
  const MonitorProgressBar({required this.progress, required this.color, required this.label, super.key});

  final double progress;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87);
    final whiteTextStyle = textStyle.copyWith(color: Colors.white);
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
              child: SizedBox.expand(child: ColoredBox(color: color)),
            ),
          ),
          Center(child: Text(label, style: textStyle)),
          Positioned.fill(
            child: ClipRect(
              clipper: _ProgressClipper(progress),
              child: SizedBox.expand(child: Center(child: Text(label, style: whiteTextStyle))),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressClipper extends CustomClipper<Rect> {
  const _ProgressClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);
  }

  @override
  bool shouldReclip(covariant _ProgressClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
