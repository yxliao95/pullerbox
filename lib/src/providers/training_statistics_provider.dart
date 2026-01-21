import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/training_statistics_calculator.dart';

final trainingStatisticsCalculatorProvider = Provider<TrainingStatisticsCalculator>((ref) {
  return TrainingStatisticsCalculator();
});
