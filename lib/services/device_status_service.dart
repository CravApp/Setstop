import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DeviceStatusService extends ChangeNotifier {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  int _batteryLevel = 100;
  int _signalLevel = 100;
  bool _isCharging = false;

  Timer? _batteryTimer;
  StreamSubscription? _connectivitySubscription;

  int get batteryLevel => _batteryLevel;
  int get signalLevel => _signalLevel;
  bool get isCharging => _isCharging;

  DeviceStatusService() {
    _init();
  }

  Future<void> _init() async {
    await _updateBattery();
    await _updateConnectivity();

    // Actualizar batería cada 30 segundos
    _batteryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateBattery();
    });

    // Escuchar cambios de conectividad
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((_) {
      _updateConnectivity();
    });
  }

  Future<void> _updateBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      _isCharging = state == BatteryState.charging;
      notifyListeners();
    } catch (_) {
      _batteryLevel = 75;
    }
  }

  Future<void> _updateConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.wifi)) {
        _signalLevel = 100;
      } else if (results.contains(ConnectivityResult.mobile)) {
        _signalLevel = 80;
      } else if (results.contains(ConnectivityResult.ethernet)) {
        _signalLevel = 100;
      } else {
        _signalLevel = 0;
      }
      notifyListeners();
    } catch (_) {
      _signalLevel = 0;
    }
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
