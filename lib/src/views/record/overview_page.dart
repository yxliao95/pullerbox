import 'package:flutter/material.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('可视化数据统计')),
      body: const Center(
        child: Text('待接入可视化数据统计', style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
      ),
    );
  }
}
