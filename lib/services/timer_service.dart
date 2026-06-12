import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerService extends ChangeNotifier {
  late Stopwatch _stopwatch;
  Timer? _ticker;
  bool _isRunning = false;

  TimerService() {
    _stopwatch = Stopwatch();
  }

  bool get isRunning => _isRunning;

  Duration get elapsed => _stopwatch.elapsed;

  String get formattedTime {
    final d = _stopwatch.elapsed;
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ff = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$hh:$mm:$ss:$ff';
  }

  void start() {
    if (!_isRunning) {
      _stopwatch.start();
      _isRunning = true;
      _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
        notifyListeners();
      });
    }
  }

  void pause() {
    if (_isRunning) {
      _stopwatch.stop();
      _isRunning = false;
      _ticker?.cancel();
      notifyListeners();
    }
  }

  void reset() {
    _stopwatch.stop();
    _stopwatch.reset();
    _isRunning = false;
    _ticker?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
