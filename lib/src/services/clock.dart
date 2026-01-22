abstract class Clock {
  const Clock();

  DateTime now();
}

class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() {
    return DateTime.now();
  }
}

class FixedClock extends Clock {
  const FixedClock(this._fixedTime);

  final DateTime _fixedTime;

  @override
  DateTime now() {
    return _fixedTime;
  }
}
