import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../provider/training_plan_provider.dart';

class TrainingPlanPage extends ConsumerStatefulWidget {
  const TrainingPlanPage({super.key});

  @override
  ConsumerState<TrainingPlanPage> createState() => _TrainingPlanPageState();
}

class _TrainingPlanPageState extends ConsumerState<TrainingPlanPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(trainingPlanProvider);
    _nameController = TextEditingController(text: state.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trainingPlanProvider);
    final controller = ref.read(trainingPlanProvider.notifier);
    final totalDurationText = _formatDuration(state.totalDurationSeconds);
    const sliverAppBarExpandedHeight = 210.0;
    const sliverAppBarCollapsedThresholdPadding = 8.0;
    const sliverAppBarTitlePadding = EdgeInsets.fromLTRB(16, 0, 16, 12);
    const sliverHeaderExpandedPadding = EdgeInsets.fromLTRB(16, 12, 16, 18);

    if (_nameController.text != state.name) {
      _nameController.text = state.name;
      _nameController.selection = TextSelection.fromPosition(TextPosition(offset: _nameController.text.length));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: false,
              expandedHeight: sliverAppBarExpandedHeight,
              backgroundColor: const Color(0xFF2A73F1),
              elevation: 0,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final topPadding = MediaQuery.of(context).padding.top;
                  final collapsedThreshold = topPadding + kToolbarHeight + sliverAppBarCollapsedThresholdPadding;
                  final isCollapsed = constraints.maxHeight <= collapsedThreshold;

                  return FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: sliverAppBarTitlePadding,
                    title: isCollapsed
                        ? _CollapsedHeaderContent(title: '总时长', duration: totalDurationText, onConnectPressed: () {})
                        : null,
                    background: _ExpandedHeaderSection(
                      title: '总时长',
                      duration: totalDurationText,
                      onConnectPressed: () {},
                      expandedPadding: sliverHeaderExpandedPadding,
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 16),
                    _PlanNameRow(controller: _nameController, onNameChanged: controller.updateName),
                    const SizedBox(height: 12),
                    _NumberCard(
                      label: '锻炼',
                      value: state.workSeconds,
                      unit: '秒',
                      onMinus: controller.decrementWork,
                      onPlus: controller.incrementWork,
                    ),
                    const SizedBox(height: 12),
                    _NumberCard(
                      label: '休息',
                      value: state.restSeconds,
                      unit: '秒',
                      onMinus: controller.decrementRest,
                      onPlus: controller.incrementRest,
                    ),
                    const SizedBox(height: 12),
                    _NumberCard(
                      label: '循环',
                      value: state.cycles,
                      unit: '次',
                      onMinus: controller.decrementCycles,
                      onPlus: controller.incrementCycles,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E2E2E),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('切换自由训练'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A73F1),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('开始'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainSeconds = seconds % 60;
    final minuteText = minutes.toString().padLeft(2, '0');
    final secondText = remainSeconds.toString().padLeft(2, '0');
    return '$minuteText:$secondText';
  }
}

class _ExpandedHeaderSection extends StatelessWidget {
  const _ExpandedHeaderSection({
    required this.title,
    required this.duration,
    required this.onConnectPressed,
    required this.expandedPadding,
  });

  final String title;
  final String duration;
  final VoidCallback onConnectPressed;
  final EdgeInsets expandedPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: expandedPadding,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF2A73F1), Color(0xFF1F5DD8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              duration,
              style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _BluetoothCard(onConnectPressed: onConnectPressed),
          ],
        ),
      ),
    );
  }
}

class _CollapsedHeaderContent extends StatelessWidget {
  const _CollapsedHeaderContent({required this.title, required this.duration, required this.onConnectPressed});

  final String title;
  final String duration;
  final VoidCallback onConnectPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Text(
                duration,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        _BluetoothIconButton(onConnectPressed: onConnectPressed),
      ],
    );
  }
}

class _BluetoothCard extends StatelessWidget {
  const _BluetoothCard({required this.onConnectPressed});

  final VoidCallback onConnectPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF3A7AF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(Icons.bluetooth, color: Color(0xFF2A73F1)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('设备未连接', style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
          _BluetoothButton(onConnectPressed: onConnectPressed),
        ],
      ),
    );
  }
}

class _BluetoothButton extends StatelessWidget {
  const _BluetoothButton({required this.onConnectPressed});

  final VoidCallback onConnectPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onConnectPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2A73F1),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: const Text('连接设备'),
    );
  }
}

class _BluetoothIconButton extends StatelessWidget {
  const _BluetoothIconButton({required this.onConnectPressed});

  final VoidCallback onConnectPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onConnectPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.bluetooth, color: Color(0xFF2A73F1), size: 20),
      ),
    );
  }
}

class _PlanNameRow extends StatelessWidget {
  const _PlanNameRow({required this.controller, required this.onNameChanged});

  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context) {
    const hintText = '输入训练名称';
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    const hintStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black38);
    const horizontalPadding = 12.0;

    return Row(
      children: <Widget>[
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final displayText = value.text.isNotEmpty ? value.text : hintText;
            final displayStyle = value.text.isNotEmpty ? textStyle : hintStyle;
            final textPainter = TextPainter(
              text: TextSpan(text: displayText, style: displayStyle),
              textDirection: Directionality.of(context),
            )..layout();
            final underlineWidth = textPainter.width + horizontalPadding * 2;

            return SizedBox(
              width: underlineWidth + 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    onChanged: onNameChanged,
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
        const Icon(Icons.edit, size: 16, color: Colors.black45),
      ],
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.onMinus,
    required this.onPlus,
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
          _AdjustButton(icon: Icons.remove, onTap: onMinus),
          const SizedBox(width: 8),
          _AdjustButton(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.icon, required this.onTap});

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
