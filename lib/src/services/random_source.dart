import 'dart:math' as math;

abstract class RandomSource {
  const RandomSource();

  double nextDouble();

  int nextInt(int max);
}

class SeededRandomSource extends RandomSource {
  SeededRandomSource({int? seed}) : _random = math.Random(seed);

  final math.Random _random;

  @override
  double nextDouble() {
    return _random.nextDouble();
  }

  @override
  int nextInt(int max) {
    return _random.nextInt(max);
  }
}
