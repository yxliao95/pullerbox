import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/training_plan_provider.dart';

class TrainingMonitorPage extends ConsumerStatefulWidget {
  const TrainingMonitorPage({super.key});

  @override
  ConsumerState<TrainingMonitorPage> createState() => _TrainingMonitorPageState();
}

class _TrainingMonitorPageState extends ConsumerState<TrainingMonitorPage> {
  static const double _sampleIntervalSeconds = 0.1;
  static const double _restMaxValue = 1.0;
  static const double _emaAlpha = 0.25;
  final math.Random _random = math.Random();

  Timer? _timer;
  bool _isPaused = false;
  bool _isSoundOn = true;
  bool _isWorking = true;
  int _currentCycle = 1;
  double _elapsedInPhase = 0.0;
  double _currentValue = 0.0;
  double _smoothedValue = 0.0;
  double _maxValue = 0.0;
  double _maxValueTime = 0.0;
  double _workPeak = 0.0;
  List<_ChartSample> _samples = <_ChartSample>[];
  List<double> _workSecondLimits = <double>[];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startPhase(isWorking: true);
    _timer = Timer.periodic(Duration(milliseconds: (_sampleIntervalSeconds * 1000).round()), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _tick() {
    if (_isPaused) {
      return;
    }
    final plan = ref.read(trainingPlanProvider);
    final phaseDuration = _isWorking ? plan.workSeconds : plan.restSeconds;
    if (phaseDuration <= 0) {
      _advancePhase(plan.workSeconds, plan.restSeconds, plan.cycles);
      return;
    }

    _elapsedInPhase += _sampleIntervalSeconds;
    final rawValue = _nextSampleValue();
    _smoothedValue = _emaAlpha * rawValue + (1 - _emaAlpha) * _smoothedValue;
    _currentValue = _smoothedValue;
    _samples = <_ChartSample>[..._samples, _ChartSample(time: _elapsedInPhase, value: _currentValue)];
    if (_samples.length > 600) {
      _samples = _samples.sublist(_samples.length - 600);
    }
    if (_isWorking && _currentValue >= _maxValue) {
      _maxValue = _currentValue;
      _maxValueTime = _elapsedInPhase;
    }

    if (_elapsedInPhase >= phaseDuration) {
      _advancePhase(plan.workSeconds, plan.restSeconds, plan.cycles);
    }
    setState(() {});
  }

  void _advancePhase(int workSeconds, int restSeconds, int totalCycles) {
    if (_isWorking) {
      if (restSeconds > 0) {
        _startPhase(isWorking: false);
      } else {
        _finishCycle(totalCycles);
      }
    } else {
      _finishCycle(totalCycles);
    }
  }

  void _finishCycle(int totalCycles) {
    if (_currentCycle >= totalCycles) {
      _isPaused = true;
      return;
    }
    _currentCycle += 1;
    _startPhase(isWorking: true);
  }

  void _startPhase({required bool isWorking}) {
    _isWorking = isWorking;
    _elapsedInPhase = 0.0;
    _samples = const <_ChartSample>[_ChartSample(time: 0.0, value: 0.0)];
    _maxValue = 0.0;
    _maxValueTime = 0.0;
    if (isWorking) {
      _workPeak = _randomInRange(35.0, 70.0);
      _workSecondLimits = <double>[_workPeak];
    } else {
      _workSecondLimits = <double>[];
    }
    _currentValue = 0.0;
    _smoothedValue = 0.0;
  }

  double _nextSampleValue() {
    if (!_isWorking) {
      return _roundToTenth(_random.nextDouble() * _restMaxValue);
    }
    final second = _elapsedInPhase.floor();
    final nextSecond = second + 1;
    final currentLimit = _limitForSecond(second);
    final nextLimit = _limitForSecond(nextSecond);
    double minLimit = math.min(currentLimit, nextLimit);
    double maxLimit = math.max(currentLimit, nextLimit);
    if (_elapsedInPhase < 1.0) {
      final progress = _elapsedInPhase.clamp(0.0, 1.0);
      maxLimit = currentLimit * progress;
      minLimit = 0.0;
    }
    return _roundToTenth(_randomInRange(minLimit, maxLimit));
  }

  double _limitForSecond(int second) {
    if (second < 0) {
      return 0.0;
    }
    if (second < _workSecondLimits.length) {
      return _workSecondLimits[second];
    }
    for (var i = _workSecondLimits.length; i <= second; i++) {
      final previous = _workSecondLimits.last;
      final decay = _randomInRange(0.7, 0.9);
      _workSecondLimits.add(previous * decay);
    }
    return _workSecondLimits[second];
  }

  double _randomInRange(double min, double max) {
    if (max <= min) {
      return min;
    }
    return min + _random.nextDouble() * (max - min);
  }

  double _roundToTenth(double value) {
    return (value * 10).roundToDouble() / 10;
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _toggleSound() {
    setState(() {
      _isSoundOn = !_isSoundOn;
    });
  }

  void _goToPreviousAction() {
    if (_isWorking) {
      if (_currentCycle == 1) {
        return;
      }
      _currentCycle -= 1;
      _startPhase(isWorking: false);
    } else {
      _startPhase(isWorking: true);
    }
    setState(() {});
  }

  void _goToNextAction() {
    final plan = ref.read(trainingPlanProvider);
    _advancePhase(plan.workSeconds, plan.restSeconds, plan.cycles);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(trainingPlanProvider);
    final totalCycles = math.max(1, plan.cycles);
    final phaseDuration = _isWorking ? plan.workSeconds : plan.restSeconds;
    final phaseProgress = phaseDuration <= 0 ? 0.0 : (_elapsedInPhase / phaseDuration).clamp(0.0, 1.0);
    final progressColor = _isWorking ? const Color(0xFF2AC41F) : const Color(0xFFFF4B4B);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 48,
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _ExitButton(onPressed: () => Navigator.of(context).maybePop()),
                    ),
                    Center(
                      child: Text(
                        '循环 $_currentCycle / $totalCycles',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _Toolbar(
                        isSoundOn: _isSoundOn,
                        isPaused: _isPaused,
                        onToggleSound: _toggleSound,
                        onPrevious: _goToPreviousAction,
                        onTogglePause: _togglePause,
                        onNext: _goToNextAction,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: _ChartPanel(
                        samples: _samples,
                        isWorking: _isWorking,
                        maxValue: _maxValue,
                        maxValueTime: _maxValueTime,
                        workPeak: _workPeak,
                        phaseDuration: phaseDuration.toDouble(),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '实时拉力：${_currentValue.toStringAsFixed(1)} KG',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),
                  ),
                  if (!_isWorking)
                    const Center(
                      child: Text(
                        '休息',
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                    ),
                ],
              ),
            ),
            _ProgressBar(
              progress: phaseProgress,
              color: progressColor,
              label: '${_elapsedInPhase.toStringAsFixed(0)} 秒',
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.isSoundOn,
    required this.isPaused,
    required this.onToggleSound,
    required this.onPrevious,
    required this.onTogglePause,
    required this.onNext,
  });

  final bool isSoundOn;
  final bool isPaused;
  final VoidCallback onToggleSound;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFE6E6E6), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CompactIconButton(
            onPressed: onToggleSound,
            icon: Icon(isSoundOn ? Icons.volume_up : Icons.volume_off, size: 20),
          ),
          _CompactIconButton(onPressed: onPrevious, icon: const Icon(Icons.skip_previous, size: 20)),
          _CompactIconButton(onPressed: onTogglePause, icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 20)),
          _CompactIconButton(onPressed: onNext, icon: const Icon(Icons.skip_next, size: 20)),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final Icon icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: const Color(0xFFE6E6E6), borderRadius: BorderRadius.circular(18)),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.close, color: Colors.black87),
        splashRadius: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.color, required this.label});

  final double progress;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(decoration: BoxDecoration(color: color)),
            ),
          ),
          Center(
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.samples,
    required this.isWorking,
    required this.maxValue,
    required this.maxValueTime,
    required this.workPeak,
    required this.phaseDuration,
  });

  final List<_ChartSample> samples;
  final bool isWorking;
  final double maxValue;
  final double maxValueTime;
  final double workPeak;
  final double phaseDuration;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        samples: samples,
        isWorking: isWorking,
        maxValue: maxValue,
        maxValueTime: maxValueTime,
        workPeak: workPeak,
        phaseDuration: phaseDuration,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.samples,
    required this.isWorking,
    required this.maxValue,
    required this.maxValueTime,
    required this.workPeak,
    required this.phaseDuration,
  });

  final List<_ChartSample> samples;
  final bool isWorking;
  final double maxValue;
  final double maxValueTime;
  final double workPeak;
  final double phaseDuration;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) {
      return;
    }
    final chartRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(chartRect, Paint()..color = const Color(0xFFF2F2F2));
    if (samples.isEmpty) {
      return;
    }

    final maxValueOnChart = _resolveYAxisMax(isWorking, maxValue);
    final path = Path();
    double firstX = 0.0;
    double firstY = size.height;
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final x = (sample.time / math.max(phaseDuration, 1.0)) * size.width;
      final y = size.height - (sample.value / maxValueOnChart) * size.height;
      if (i == 0) {
        firstX = x;
        firstY = y;
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final currentTime = samples.last.time;
    final endX = (currentTime / math.max(phaseDuration, 1.0)) * size.width;
    final fillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(firstX, size.height)
      ..lineTo(firstX, firstY)
      ..addPath(path, Offset.zero)
      ..lineTo(endX, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillColor = isWorking ? const Color(0x332AC41F) : const Color(0x33FF4B4B);
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    if (isWorking && maxValue > 0) {
      final maxX = (maxValueTime / math.max(phaseDuration, 1.0)) * size.width;
      final maxY = size.height - (maxValue / maxValueOnChart) * size.height;
      final linePaint = Paint()
        ..color = const Color(0xFFB0B0B0)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(maxX, size.height), Offset(maxX, maxY), linePaint);
    }

    final strokeColor = isWorking ? const Color(0xFF2AC41F) : const Color(0xFFFF4B4B);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (isWorking && maxValue > 0) {
      final maxX = (maxValueTime / math.max(phaseDuration, 1.0)) * size.width;
      final maxY = size.height - (maxValue / maxValueOnChart) * size.height;
      final dotPaint = Paint()..color = strokeColor;
      canvas.drawCircle(Offset(maxX, maxY), 4, dotPaint);

      final labelText = 'MAX ${maxValue.toStringAsFixed(1)} kg';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var textX = maxX + 8;
      if (textX + textPainter.width > size.width) {
        textX = maxX - 8 - textPainter.width;
      }
      final textY = (maxY - textPainter.height - 6).clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.isWorking != isWorking ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.maxValueTime != maxValueTime ||
        oldDelegate.workPeak != workPeak ||
        oldDelegate.phaseDuration != phaseDuration;
  }

  double _resolveYAxisMax(bool isWorking, double currentMaxValue) {
    var yMax = 50.0;
    while (currentMaxValue > yMax * 0.7) {
      yMax += 10.0;
    }
    return yMax;
  }
}

class _ChartSample {
  const _ChartSample({required this.time, required this.value});

  final double time;
  final double value;
}
