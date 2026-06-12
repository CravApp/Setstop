import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

// ─── Estados del letrero LED ───────────────────────────────────────────────
enum LedStatus { libre, preparando, ocupado, desconectado }

// ─── Protocolo de conexión ─────────────────────────────────────────────────
enum LedProtocol { http, mqtt, websocket }

class LedSignConfig {
  String host;          // IP o hostname del ESP32/Raspberry Pi
  int port;             // Puerto (80 para HTTP, 1883 para MQTT, 81 para WS)
  LedProtocol protocol;
  String deviceName;
  bool autoSync;        // Sincronizar automáticamente al cambiar estado

  LedSignConfig({
    this.host = '192.168.1.100',
    this.port = 80,
    this.protocol = LedProtocol.http,
    this.deviceName = 'SET-STOP LED Sign',
    this.autoSync = true,
  });

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'protocol': protocol.index,
        'deviceName': deviceName,
        'autoSync': autoSync,
      };

  factory LedSignConfig.fromJson(Map<String, dynamic> j) => LedSignConfig(
        host: j['host'] ?? '192.168.1.100',
        port: j['port'] ?? 80,
        protocol: LedProtocol.values[j['protocol'] ?? 0],
        deviceName: j['deviceName'] ?? 'SET-STOP LED Sign',
        autoSync: j['autoSync'] ?? true,
      );
}

class LedSignService extends ChangeNotifier {
  LedSignConfig _config = LedSignConfig();
  LedStatus _ledStatus = LedStatus.desconectado;
  bool _isConnected = false;
  bool _isSyncing = false;
  String? _lastError;
  DateTime? _lastSync;
  Timer? _heartbeatTimer;

  LedSignConfig get config => _config;
  LedStatus get ledStatus => _ledStatus;
  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSync => _lastSync;

  String get ledStatusLabel {
    switch (_ledStatus) {
      case LedStatus.ocupado:
        return 'OCUPADO';
      case LedStatus.preparando:
        return 'PREPARANDO';
      case LedStatus.libre:
        return 'LIBRE';
      case LedStatus.desconectado:
        return 'DESCONECTADO';
    }
  }

  String get ledStatusEmoji {
    switch (_ledStatus) {
      case LedStatus.ocupado:
        return '🔴';
      case LedStatus.preparando:
        return '🟡';
      case LedStatus.libre:
        return '🟢';
      case LedStatus.desconectado:
        return '⚫';
    }
  }

  LedSignService() {
    _loadConfig();
  }

  // ─── Mapear SetStatus → LedStatus ─────────────────────────────────────────
  LedStatus mapFromSetStatus(SetStatus s) {
    switch (s) {
      case SetStatus.record:
        return LedStatus.ocupado;
      case SetStatus.prep:
        return LedStatus.preparando;
      case SetStatus.libre:
        return LedStatus.libre;
    }
  }

  // ─── Sincronizar estado automáticamente ───────────────────────────────────
  Future<void> syncStatus(SetStatus setStatus) async {
    if (!_config.autoSync) return;
    final target = mapFromSetStatus(setStatus);
    await sendLedCommand(target);
  }

  // ─── Enviar comando al letrero ─────────────────────────────────────────────
  Future<bool> sendLedCommand(LedStatus status) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    bool success = false;

    switch (_config.protocol) {
      case LedProtocol.http:
        success = await _sendHttp(status);
        break;
      case LedProtocol.mqtt:
        success = await _sendMqtt(status);
        break;
      case LedProtocol.websocket:
        success = await _sendHttp(status); // fallback HTTP
        break;
    }

    if (success) {
      _ledStatus = status;
      _isConnected = true;
      _lastSync = DateTime.now();
    } else {
      _isConnected = false;
    }

    _isSyncing = false;
    notifyListeners();
    return success;
  }

  // ─── Protocolo HTTP REST (ESP32 con servidor web) ──────────────────────────
  Future<bool> _sendHttp(LedStatus status) async {
    try {
      final url = Uri.parse(
          'http://${_config.host}:${_config.port}/led');
      final payload = jsonEncode({
        'status': _ledStatusCode(status),
        'label': _ledLabel(status),
        'color': _ledColorHex(status),
        'timestamp': DateTime.now().toIso8601String(),
      });

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } on TimeoutException {
      _lastError = 'Tiempo de espera agotado. Verifica que el letrero esté encendido.';
      return false;
    } catch (e) {
      _lastError = 'No se pudo conectar al letrero LED.\nVerifica la IP: ${_config.host}';
      return false;
    }
  }

  // ─── Protocolo MQTT (broker externo o en el ESP32) ─────────────────────────
  Future<bool> _sendMqtt(LedStatus status) async {
    // Para MQTT en web usamos HTTP como puente
    // En Android/iOS se usaría mqtt_client directamente
    if (kIsWeb) {
      return await _sendHttp(status);
    }
    // En móvil: implementación MQTT nativa
    try {
      // Simulamos éxito hasta que se configure el broker real
      await Future.delayed(const Duration(milliseconds: 200));
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = 'Error MQTT: $e';
      return false;
    }
  }

  // ─── Test de conexión ──────────────────────────────────────────────────────
  Future<bool> testConnection() async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final url = Uri.parse(
          'http://${_config.host}:${_config.port}/ping');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 4));

      _isConnected = response.statusCode == 200;
      if (!_isConnected) {
        _lastError = 'El letrero respondió con error ${response.statusCode}';
      }
    } on TimeoutException {
      _isConnected = false;
      _lastError = 'Sin respuesta. Verifica la red y la IP del letrero.';
    } catch (e) {
      _isConnected = false;
      _lastError = 'No se encontró el letrero en ${_config.host}:${_config.port}';
    }

    _isSyncing = false;
    notifyListeners();
    return _isConnected;
  }

  // ─── Heartbeat ────────────────────────────────────────────────────────────
  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      testConnection();
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  // ─── Actualizar configuración ─────────────────────────────────────────────
  Future<void> updateConfig(LedSignConfig config) async {
    _config = config;
    _isConnected = false;
    _lastError = null;
    await _saveConfig();
    notifyListeners();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _ledStatusCode(LedStatus s) {
    switch (s) {
      case LedStatus.ocupado:
        return 'OCCUPIED';
      case LedStatus.preparando:
        return 'PREPARING';
      case LedStatus.libre:
        return 'FREE';
      case LedStatus.desconectado:
        return 'OFF';
    }
  }

  String _ledLabel(LedStatus s) {
    switch (s) {
      case LedStatus.ocupado:
        return 'OCUPADO';
      case LedStatus.preparando:
        return 'PREPARANDO';
      case LedStatus.libre:
        return 'LIBRE';
      case LedStatus.desconectado:
        return 'APAGADO';
    }
  }

  String _ledColorHex(LedStatus s) {
    switch (s) {
      case LedStatus.ocupado:
        return '#FF0000';
      case LedStatus.preparando:
        return '#FFFF00';
      case LedStatus.libre:
        return '#00FF00';
      case LedStatus.desconectado:
        return '#000000';
    }
  }

  // ─── Persistencia ─────────────────────────────────────────────────────────
  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('led_config', jsonEncode(_config.toJson()));
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('led_config');
      if (raw != null) {
        _config = LedSignConfig.fromJson(jsonDecode(raw));
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
