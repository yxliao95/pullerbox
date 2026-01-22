import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/clock.dart';
import '../services/random_source.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final randomSourceProvider = Provider<RandomSource>((ref) => SeededRandomSource());
