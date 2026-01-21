import 'package:flutter/material.dart';

class PanelEntry {
  const PanelEntry(this.label, this.value);

  final String label;
  final String value;
}

class PanelGrid extends StatelessWidget {
  const PanelGrid({required this.entries, required this.isSingleColumn, super.key});

  final List<PanelEntry> entries;
  final bool isSingleColumn;

  @override
  Widget build(BuildContext context) {
    if (isSingleColumn) {
      return PanelColumn(entries: entries, removeGap: false);
    }
    final leftEntries = <PanelEntry>[];
    final rightEntries = <PanelEntry>[];
    for (var i = 0; i < entries.length; i += 1) {
      if (i.isEven) {
        leftEntries.add(entries[i]);
      } else {
        rightEntries.add(entries[i]);
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: PanelColumn(entries: leftEntries, removeGap: true)),
        const SizedBox(width: 16),
        Expanded(child: PanelColumn(entries: rightEntries, removeGap: true)),
      ],
    );
  }
}

class PanelColumn extends StatelessWidget {
  const PanelColumn({required this.entries, required this.removeGap, super.key});

  final List<PanelEntry> entries;
  final bool removeGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < entries.length; i += 1) ...<Widget>[
          if (i > 0) const SizedBox(height: 10),
          PanelRow(label: entries[i].label, value: entries[i].value, removeGap: removeGap),
        ],
      ],
    );
  }
}

class PanelRow extends StatelessWidget {
  const PanelRow({required this.label, required this.value, required this.removeGap, super.key});

  final String label;
  final String value;
  final bool removeGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E6E)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!removeGap) const SizedBox(width: 30),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class FreeTrainingHelpItem extends StatelessWidget {
  const FreeTrainingHelpItem({required this.label, required this.description, super.key});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: <TextSpan>[
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: description),
          ],
        ),
      ),
    );
  }
}
