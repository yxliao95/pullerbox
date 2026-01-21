import 'package:flutter/material.dart';

class PlanListTile extends StatelessWidget {
  const PlanListTile({
    required this.index,
    required this.title,
    required this.valuesText,
    required this.isActive,
    required this.isEditing,
    required this.isChecked,
    required this.shouldWrapTitle,
    required this.onTap,
    required this.onToggleCheck,
    super.key,
  });

  final int index;
  final String title;
  final String valuesText;
  final bool isActive;
  final bool isEditing;
  final bool isChecked;
  final bool shouldWrapTitle;
  final VoidCallback onTap;
  final VoidCallback onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final activeColor = isActive ? const Color(0xFF2A73F1) : const Color(0xFF1E1E1E);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: activeColor),
                  maxLines: shouldWrapTitle ? null : 1,
                  overflow: shouldWrapTitle ? TextOverflow.visible : TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('锻炼 / 休息 / 循环', style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B))),
                  const SizedBox(height: 4),
                  Text(valuesText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 16),
              if (isEditing)
                Checkbox(value: isChecked, onChanged: (_) => onToggleCheck())
              else
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, color: Color(0xFF1E1E1E)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
