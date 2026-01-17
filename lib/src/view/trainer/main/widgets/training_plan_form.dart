import 'dart:math' as math;

import 'package:flutter/material.dart';

class PlanNameRow extends StatelessWidget {
  const PlanNameRow({required this.controller, required this.onNameChanged, super.key});

  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context) {
    const hintText = '输入训练名称';
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    const hintStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black38);
    const horizontalPadding = 12.0;
    const iconWidth = 16.0;
    const iconSpacing = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTextWidth = math.max(0.0, constraints.maxWidth - iconWidth - iconSpacing);

        return Row(
          children: <Widget>[
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final displayText = value.text.isNotEmpty ? value.text : hintText;
                final displayStyle = value.text.isNotEmpty ? textStyle : hintStyle;
                final singleLinePainter = TextPainter(
                  text: TextSpan(text: displayText, style: displayStyle),
                  textDirection: Directionality.of(context),
                  maxLines: 1,
                )..layout();
                final availableLineWidth = math.max(0.0, maxTextWidth - horizontalPadding * 2);
                final shouldWrap = singleLinePainter.width > availableLineWidth;
                final textPainter = TextPainter(
                  text: TextSpan(text: displayText, style: displayStyle),
                  textDirection: Directionality.of(context),
                )..layout(maxWidth: availableLineWidth);
                final underlineWidth =
                    shouldWrap ? maxTextWidth : math.min(textPainter.width + horizontalPadding * 2, maxTextWidth);
                final fieldWidth = shouldWrap ? maxTextWidth : math.min(underlineWidth + 8, maxTextWidth);

                return SizedBox(
                  width: fieldWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: controller,
                        onChanged: onNameChanged,
                        minLines: 1,
                        maxLines: shouldWrap ? null : 1,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: hintText,
                          hintStyle: hintStyle,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 2),
                        ),
                        style: textStyle,
                      ),
                      Container(height: 1, width: underlineWidth, color: const Color(0xFFE1E1E1)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: iconSpacing),
            const Icon(Icons.edit, size: 16, color: Colors.black45),
          ],
        );
      },
    );
  }
}

class NumberCard extends StatelessWidget {
  const NumberCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.onMinus,
    required this.onPlus,
    super.key,
  });

  final String label;
  final int value;
  final String unit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(label, style: const TextStyle(color: Colors.black, fontSize: 16)),
                  const SizedBox(width: 20),
                  Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text(unit, style: const TextStyle(color: Color(0xFF6C6C6C), fontSize: 12)),
                ],
              ),
            ),
          ),
          AdjustButton(icon: Icons.remove, onTap: onMinus),
          const SizedBox(width: 8),
          AdjustButton(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class AdjustButton extends StatelessWidget {
  const AdjustButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: Color(0xFFF0F0F0), shape: BoxShape.circle),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
