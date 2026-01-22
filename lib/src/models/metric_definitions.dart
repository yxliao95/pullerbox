class MetricVisibility {
  const MetricVisibility({this.showInSummary = true, this.showInFilter = true, this.showInDetail = true});

  final bool showInSummary;
  final bool showInFilter;
  final bool showInDetail;

  MetricVisibility copyWith({bool? showInSummary, bool? showInFilter, bool? showInDetail}) {
    return MetricVisibility(
      showInSummary: showInSummary ?? this.showInSummary,
      showInFilter: showInFilter ?? this.showInFilter,
      showInDetail: showInDetail ?? this.showInDetail,
    );
  }
}

class MetricDefinition<T> {
  const MetricDefinition({
    required this.metric,
    required this.label,
    String? shortLabel,
    required this.description,
    this.visibility = const MetricVisibility(),
  }) : shortLabel = shortLabel ?? label;

  final T metric;
  final String label;
  final String shortLabel;
  final String description;
  final MetricVisibility visibility;
}

class MetricGuideDefinition {
  const MetricGuideDefinition({required this.label, required this.description});

  final String label;
  final String description;
}

enum RecordTrainingType { timed, free }

enum TimedSummaryMetric {
  maxStrength,
  maxControlStrength,
  controlCycles,
  fatigueSignal,
  minControlStrength,
  dropMean,
  dropMax,
  dropStd,
}

enum FreeSummaryMetric { totalDuration, controlMax, longestControl, windowMean, windowDelta, deltaMax, deltaMin }

enum TimedBarMetric { averageStrength, maxStrength, controlStrength }

const List<MetricDefinition<TimedSummaryMetric>> timedSummaryMetricDefinitions = <MetricDefinition<TimedSummaryMetric>>[
  MetricDefinition(metric: TimedSummaryMetric.maxStrength, label: '力量峰值', description: '遍历全程采样序列取最大值，作为本次训练的峰值拉力。'),
  MetricDefinition(
    metric: TimedSummaryMetric.maxControlStrength,
    label: '最大控制力量',
    shortLabel: "最大力量",
    description: '取各循环控制力量的最大值。',
  ),
  MetricDefinition(
    metric: TimedSummaryMetric.controlCycles,
    label: '最大力量控制循环数',
    shortLabel: '控制循环数',
    description: '按循环统计。若该循环满足【从进入发力持续阶段开始，到循环结束，始终保持最大控制力量】，则计为1次控制循环并累加。',
  ),
  MetricDefinition(
    metric: TimedSummaryMetric.fatigueSignal,
    label: '力竭信号',
    description: '当控制力量持续低于阈值且超过容差时间，触发力竭标记；记录首次触发的循环与时间点。阈值为前两次循环的控制力量区间集合的中位数的80%，容差时间为2秒。标记位置为判断窗口的起始。',
  ),
  MetricDefinition(
    metric: TimedSummaryMetric.minControlStrength,
    label: '最低控制力量',
    shortLabel: '最低力量',
    description:
        '从力竭起始时刻开始直到所有循环结束，期间所有循环的持续发力阶段数据合并成集合，取所有稳定窗口均值的最小值。窗口滑动采样，步长为1秒。窗口的变异系数小于 0.05 时，视为稳定窗口。衡量力竭之后，能够稳定维持的最低力量水平。',
  ),
  MetricDefinition(
    metric: TimedSummaryMetric.dropMean,
    label: '力竭后力量降幅均值',
    shortLabel: '力竭降幅均值',
    description: '以最大控制力量为基准，计算力竭发生时及之后各循环的平均力量的下降比例，取平均值。',
  ),
  MetricDefinition(
    metric: TimedSummaryMetric.dropMax,
    label: '力竭后力量降幅最大值',
    shortLabel: '力竭降幅最大',
    description: '以最大控制力量为基准，计算力竭发生时及之后各循环的平均力量的下降比例，取最大下降值。',
  ),
  MetricDefinition(
    metric: TimedSummaryMetric.dropStd,
    label: '力竭后力量降幅标准差',
    shortLabel: '力竭降幅标准差',
    description: '以最大控制力量为基准，计算力竭发生时及之后各循环的平均力量的下降比例，求标准差；衡量下降幅度的波动程度。',
  ),
];

const List<MetricGuideDefinition> timedGuideSupplementDefinitions = <MetricGuideDefinition>[
  MetricGuideDefinition(label: '稳定最大力量', description: '每次循环，选择力量峰值 0.99 分位数的值作为稳定最大力量。'),
  MetricGuideDefinition(label: '控制力量', description: '每次循环，选择稳定最大力量 95% 以上的数值进行统计，取中位数。'),
  MetricGuideDefinition(label: '发力准备阶段', description: '在每次循环的开始，力量最低值持续上升的过程，被标记为发力准备阶段。该阶段力量不计入统计。'),
  MetricGuideDefinition(
    label: '发力持续阶段',
    description: '在每次循环的开始，在连续时间窗口达到控制力量后，直至循环结束，被标记为发力持续阶段。仅该阶段力量计入统计。初始连续时间窗口为 0.3 秒，若标记失败，则缩短窗口，直至标记成功。',
  ),
];

const List<MetricDefinition<FreeSummaryMetric>> freeSummaryMetricDefinitions = <MetricDefinition<FreeSummaryMetric>>[
  MetricDefinition(metric: FreeSummaryMetric.totalDuration, label: '总时长', description: '本次自由训练累计时长。'),
  MetricDefinition(metric: FreeSummaryMetric.controlMax, label: '最大控制力量', description: '达到力量峰值 95% 以上区间的中位数。'),
  MetricDefinition(metric: FreeSummaryMetric.longestControl, label: '最长连续控制', description: '力量连续不低于最大控制力量 95% 的最长时长。'),
  MetricDefinition(metric: FreeSummaryMetric.windowMean, label: '1s均值', description: '最近一个完整 1 秒窗口的平均力量。'),
  MetricDefinition(metric: FreeSummaryMetric.windowDelta, label: '1s变化', description: '当前 1 秒均值减去上一个 1 秒均值。'),
  MetricDefinition(metric: FreeSummaryMetric.deltaMax, label: '1s最大增长', description: '所有 1 秒变化中的最大上升值。'),
  MetricDefinition(metric: FreeSummaryMetric.deltaMin, label: '1s最大下降', description: '所有 1 秒变化中的最大下降值。'),
];

const List<MetricGuideDefinition> freeGuideSupplementDefinitions = <MetricGuideDefinition>[];

final Map<TimedSummaryMetric, MetricDefinition<TimedSummaryMetric>> timedSummaryMetricDefinitionMap =
    <TimedSummaryMetric, MetricDefinition<TimedSummaryMetric>>{
      for (final definition in timedSummaryMetricDefinitions) definition.metric: definition,
    };

final Map<FreeSummaryMetric, MetricDefinition<FreeSummaryMetric>> freeSummaryMetricDefinitionMap =
    <FreeSummaryMetric, MetricDefinition<FreeSummaryMetric>>{
      for (final definition in freeSummaryMetricDefinitions) definition.metric: definition,
    };

String recordTrainingTypeLabel(RecordTrainingType type) {
  switch (type) {
    case RecordTrainingType.timed:
      return '计时训练';
    case RecordTrainingType.free:
      return '自由训练';
  }
}

String timedBarMetricLabel(TimedBarMetric metric) {
  switch (metric) {
    case TimedBarMetric.averageStrength:
      return '平均力量';
    case TimedBarMetric.maxStrength:
      return '最大力量';
    case TimedBarMetric.controlStrength:
      return '控制力量';
  }
}
