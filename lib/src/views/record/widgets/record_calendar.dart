import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RecordCalendar extends StatefulWidget {
  const RecordCalendar({required this.recordDates, super.key});

  final List<DateTime> recordDates;

  @override
  State<RecordCalendar> createState() => _RecordCalendarState();
}

class _RecordCalendarState extends State<RecordCalendar> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final recordDayKeys = widget.recordDates.map(_dateKey).toSet();
    final daysInMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    final leadingEmpty = DateTime(_displayMonth.year, _displayMonth.month, 1).weekday - 1;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final cellCount = rows * 7;
    const weekLabels = <String>['一', '二', '三', '四', '五', '六', '日'];

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CalendarHeader(
            monthLabel: _formatMonth(_displayMonth),
            onPrevious: _goToPreviousMonth,
            onNext: _goToNextMonth,
            onTapMonth: _showMonthPicker,
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
          _CalendarBody(
            weekLabels: weekLabels,
            cellCount: cellCount,
            leadingEmpty: leadingEmpty,
            daysInMonth: daysInMonth,
            displayMonth: _displayMonth,
            today: today,
            recordDayKeys: recordDayKeys,
            horizontalPadding: const EdgeInsets.symmetric(horizontal: 24),
            isToday: _isToday,
          ),
        ],
      ),
    );
  }

  void _goToPreviousMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    });
  }

  void _showMonthPicker() {
    final now = DateTime.now();
    final startYear = now.year - 5;
    final endYear = now.year + 5;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return _MonthPickerSheet(
          startYear: startYear,
          endYear: endYear,
          initialYear: _displayMonth.year,
          initialMonth: _displayMonth.month,
          onConfirm: (year, month) {
            setState(() {
              _displayMonth = DateTime(year, month);
            });
            Navigator.of(context).pop();
          },
          onToday: () {
            setState(() {
              _displayMonth = DateTime(now.year, now.month);
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  bool _isToday(int dayNumber, DateTime today) {
    return _displayMonth.year == today.year && _displayMonth.month == today.month && dayNumber == today.day;
  }

  String _formatMonth(DateTime value) => '${value.year}年 ${value.month}月';
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.monthLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onTapMonth,
  });

  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTapMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          color: const Color(0xFF5B5B5B),
          tooltip: '上个月',
          padding: EdgeInsets.zero,
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: onTapMonth,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(monthLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 16, color: Color(0xFF5B5B5B)),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          color: const Color(0xFF5B5B5B),
          tooltip: '下个月',
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell.day({required this.dayNumber, required this.isToday, required this.hasTraining})
    : isEmpty = false;

  const _CalendarCell.empty() : dayNumber = null, isToday = false, hasTraining = false, isEmpty = true;

  final int? dayNumber;
  final bool isToday;
  final bool hasTraining;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return const SizedBox.shrink();
    }
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        if (hasTraining)
          Positioned(
            left: 6,
            right: 6,
            bottom: 3,
            child: Container(
              height: 2,
              decoration: BoxDecoration(color: const Color(0xFF2F7BEA), borderRadius: BorderRadius.circular(2)),
            ),
          ),
        Text(
          dayNumber.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: isToday ? FontWeight.w900 : (hasTraining ? FontWeight.w800 : FontWeight.normal),
            color: isToday
                ? const Color(0xFF2F7BEA)
                : (hasTraining ? const Color(0xFF2C2C2C) : const Color(0xFF2C2C2C)),
          ),
        ),
      ],
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.weekLabels,
    required this.cellCount,
    required this.leadingEmpty,
    required this.daysInMonth,
    required this.displayMonth,
    required this.today,
    required this.recordDayKeys,
    required this.horizontalPadding,
    required this.isToday,
  });

  final List<String> weekLabels;
  final int cellCount;
  final int leadingEmpty;
  final int daysInMonth;
  final DateTime displayMonth;
  final DateTime today;
  final Set<int> recordDayKeys;
  final EdgeInsetsGeometry horizontalPadding;
  final bool Function(int dayNumber, DateTime today) isToday;

  @override
  Widget build(BuildContext context) {
    const crossAxisSpacing = 5.0; // 下面三个值调整日历大小
    const mainAxisSpacing = 2.0;
    const childAspectRatio = 1.4;
    return Padding(
      padding: horizontalPadding,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: weekLabels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: crossAxisSpacing,
              childAspectRatio: 2,
            ),
            itemBuilder: (context, index) {
              return Center(
                child: Text(weekLabels[index], style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
              );
            },
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingEmpty + 1;
              if (index < leadingEmpty || dayNumber > daysInMonth) {
                return const _CalendarCell.empty();
              }
              return _CalendarCell.day(
                dayNumber: dayNumber,
                isToday: isToday(dayNumber, today),
                hasTraining: recordDayKeys.contains(
                  _dateKey(DateTime(displayMonth.year, displayMonth.month, dayNumber)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.startYear,
    required this.endYear,
    required this.initialYear,
    required this.initialMonth,
    required this.onConfirm,
    required this.onToday,
  });

  final int startYear;
  final int endYear;
  final int initialYear;
  final int initialMonth;
  final void Function(int year, int month) onConfirm;
  final VoidCallback onToday;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _selectedYear;
  late int _selectedMonth;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear.clamp(widget.startYear, widget.endYear);
    _selectedMonth = widget.initialMonth.clamp(1, 12);
    _yearController = FixedExtentScrollController(initialItem: _selectedYear - widget.startYear);
    _monthController = FixedExtentScrollController(initialItem: _selectedMonth - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 280,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: widget.onToday,
                    child: const Text('回到今日', style: TextStyle(color: Color(0xFF2F7BEA))),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => widget.onConfirm(_selectedYear, _selectedMonth),
                    child: const Text('确定', style: TextStyle(color: Color(0xFF2F7BEA))),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: _yearController,
                              itemExtent: 36,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  _selectedYear = widget.startYear + index;
                                });
                              },
                              children: <Widget>[
                                for (int year = widget.startYear; year <= widget.endYear; year++)
                                  Center(child: Text(year.toString())),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text('年', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: _monthController,
                              itemExtent: 36,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  _selectedMonth = index + 1;
                                });
                              },
                              children: <Widget>[
                                for (int month = 1; month <= 12; month++) Center(child: Text(month.toString())),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text('月', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _dateKey(DateTime value) => value.year * 10000 + value.month * 100 + value.day;
