import 'package:flutter/material.dart';

import 'training_compare_page.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('可视化数据统计'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '训练比较'),
              Tab(text: '趋势变化'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            TrainingComparePage(),
            _OverviewPlaceholder(title: '趋势变化'),
          ],
        ),
      ),
    );
  }
}

class _OverviewPlaceholder extends StatelessWidget {
  const _OverviewPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$title 暂未接入', style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
    );
  }
}
