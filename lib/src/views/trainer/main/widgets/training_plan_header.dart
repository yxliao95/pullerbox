import 'package:flutter/material.dart';

class TrainingPlanExpandedHeader extends StatelessWidget {
  const TrainingPlanExpandedHeader({
    required this.title,
    required this.duration,
    required this.onConnectPressed,
    required this.expandedPadding,
    required this.isFreeTraining,
    required this.isDeviceConnected,
    super.key,
  });

  final String title;
  final String duration;
  final VoidCallback onConnectPressed;
  final EdgeInsets expandedPadding;
  final bool isFreeTraining;
  final bool isDeviceConnected;

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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (isFreeTraining)
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700),
                      )
                    else ...<Widget>[
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        duration,
                        style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: BluetoothCard(onConnectPressed: onConnectPressed, isDeviceConnected: isDeviceConnected),
            ),
          ],
        ),
      ),
    );
  }
}

class TrainingPlanCollapsedHeader extends StatelessWidget {
  const TrainingPlanCollapsedHeader({
    required this.title,
    required this.duration,
    required this.onConnectPressed,
    required this.isFreeTraining,
    required this.isDeviceConnected,
    super.key,
  });

  final String title;
  final String duration;
  final VoidCallback onConnectPressed;
  final bool isFreeTraining;
  final bool isDeviceConnected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: isFreeTraining
              ? Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                )
              : Row(
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
        BluetoothIconButton(onConnectPressed: onConnectPressed, isDeviceConnected: isDeviceConnected),
      ],
    );
  }
}

class BluetoothCard extends StatelessWidget {
  const BluetoothCard({required this.onConnectPressed, required this.isDeviceConnected, super.key});

  final VoidCallback onConnectPressed;
  final bool isDeviceConnected;

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
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(
              isDeviceConnected ? Icons.bluetooth : Icons.bluetooth_disabled,
              color: isDeviceConnected ? const Color(0xFF2A73F1) : const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isDeviceConnected ? '设备已连接' : '设备未连接',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          BluetoothButton(onConnectPressed: onConnectPressed, isDeviceConnected: isDeviceConnected),
        ],
      ),
    );
  }
}

class BluetoothButton extends StatelessWidget {
  const BluetoothButton({required this.onConnectPressed, required this.isDeviceConnected, super.key});

  final VoidCallback onConnectPressed;
  final bool isDeviceConnected;

  @override
  Widget build(BuildContext context) {
    final buttonText = isDeviceConnected ? '断开连接' : '连接设备';
    final textColor = isDeviceConnected ? const Color(0xFFE53935) : const Color(0xFF2A73F1);
    return ElevatedButton(
      onPressed: onConnectPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(buttonText),
    );
  }
}

class BluetoothIconButton extends StatelessWidget {
  const BluetoothIconButton({required this.onConnectPressed, required this.isDeviceConnected, super.key});

  final VoidCallback onConnectPressed;
  final bool isDeviceConnected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onConnectPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Icon(
          isDeviceConnected ? Icons.bluetooth : Icons.bluetooth_disabled,
          color: isDeviceConnected ? const Color(0xFF2A73F1) : const Color(0xFF9E9E9E),
          size: 20,
        ),
      ),
    );
  }
}
