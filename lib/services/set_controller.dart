import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/session_model.dart';
import 'timer_service.dart';

class SetController extends ChangeNotifier {
  final TimerService timerService;
  final SessionModel _session = SessionModel();

  SetController({required this.timerService});

  SetStatus get status => _session.status;
  int get tema => _session.tema;
  int get escena => _session.escena;
  String get sceneLabel => _session.sceneLabel;

  Future<void> init() async {
    await _loadSession();
    await WakelockPlus.enable();
  }

  void changeStatus(SetStatus newStatus) {
    if (_session.status == newStatus) return;

    _session.status = newStatus;

    switch (newStatus) {
      case SetStatus.record:
        timerService.start();
        HapticFeedback.heavyImpact();
        break;
      case SetStatus.prep:
        timerService.pause();
        HapticFeedback.mediumImpact();
        break;
      case SetStatus.libre:
        timerService.reset();
        HapticFeedback.lightImpact();
        break;
    }

    notifyListeners();
    _saveSession();
  }

  void incrementTema() {
    _session.tema = (_session.tema % 99) + 1;
    notifyListeners();
    _saveSession();
  }

  void decrementTema() {
    _session.tema = _session.tema > 1 ? _session.tema - 1 : 99;
    notifyListeners();
    _saveSession();
  }

  void incrementEscena() {
    _session.escena = (_session.escena % 99) + 1;
    notifyListeners();
    _saveSession();
  }

  void decrementEscena() {
    _session.escena = _session.escena > 1 ? _session.escena - 1 : 99;
    notifyListeners();
    _saveSession();
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('tema', _session.tema);
      await prefs.setInt('escena', _session.escena);
    } catch (_) {}
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _session.tema = prefs.getInt('tema') ?? 1;
      _session.escena = prefs.getInt('escena') ?? 1;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }
}
