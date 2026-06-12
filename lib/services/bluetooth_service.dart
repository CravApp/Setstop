import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

// ─── En web no existe Bluetooth Serial, usamos stub ─────────────────────────
// En Android usamos flutter_bluetooth_serial real
// La arquitectura permite que en web funcione en modo "simulación"

/// Estados posibles de la conexión Bluetooth
enum BtConnectionState {
  disabled,      // Bluetooth apagado en el dispositivo
  enabled,       // Bluetooth encendido, sin conectar
  scanning,      // Buscando dispositivos
  connecting,    // Conectando...
  connected,     // Conectado al ESP32
  disconnected,  // Se desconectó inesperadamente
  error,         // Error de conexión
}

/// Modelo de dispositivo Bluetooth encontrado
class BtDevice {
  final String name;
  final String address;
  final int rssi; // señal en dBm
  bool isBonded;  // ya vinculado

  BtDevice({
    required this.name,
    required this.address,
    this.rssi = -60,
    this.isBonded = false,
  });

  String get displayName => name.isNotEmpty ? name : 'Dispositivo ($address)';

  String get signalStrength {
    if (rssi >= -60) return 'Excelente';
    if (rssi >= -70) return 'Buena';
    if (rssi >= -80) return 'Regular';
    return 'Débil';
  }

  int get signalPercent {
    // Convertir dBm (-100 a -40) a porcentaje
    final clamped = rssi.clamp(-100, -40);
    return (((clamped + 100) / 60) * 100).round().clamp(0, 100);
  }
}

/// Protocolo de comandos enviados al ESP32 via Bluetooth
/// El ESP32 recibirá strings terminados en '\n'
class BtCommand {
  // Comandos de estado del set
  static const String occupied  = 'SET:OCCUPIED\n';   // Rojo  - OCUPADO
  static const String preparing = 'SET:PREPARING\n';  // Amarillo - PREPARANDO
  static const String free      = 'SET:FREE\n';       // Verde - LIBRE
  static const String ping      = 'PING\n';           // Verificar conexión
  static const String off       = 'SET:OFF\n';        // Apagar letrero

  /// Mapa de SetStatus → comando BT
  static String fromSetStatus(SetStatus s) {
    switch (s) {
      case SetStatus.record: return occupied;
      case SetStatus.prep:   return preparing;
      case SetStatus.libre:  return free;
    }
  }

  /// Color HEX para enviar al letrero LED RGB
  static String colorFromSetStatus(SetStatus s) {
    switch (s) {
      case SetStatus.record: return 'COLOR:FF0000\n';  // Rojo
      case SetStatus.prep:   return 'COLOR:FFFF00\n';  // Amarillo
      case SetStatus.libre:  return 'COLOR:00FF00\n';  // Verde
    }
  }

  /// Texto para el display del letrero
  static String labelFromSetStatus(SetStatus s) {
    switch (s) {
      case SetStatus.record: return 'TEXT:OCUPADO\n';
      case SetStatus.prep:   return 'TEXT:PREPARANDO\n';
      case SetStatus.libre:  return 'TEXT:LIBRE\n';
    }
  }
}

/// Servicio principal de Bluetooth — abstracción multiplataforma
class BluetoothSignService extends ChangeNotifier {
  // ── Estado interno ─────────────────────────────────────────────────────────
  BtConnectionState _state      = BtConnectionState.enabled;
  List<BtDevice>    _devices    = [];
  BtDevice?         _connected;
  String?           _lastError;
  String?           _lastCommand;
  DateTime?         _lastSent;
  bool              _autoReconnect = true;
  int               _messagesSent  = 0;

  // Guardamos MAC del último dispositivo conectado para reconectar
  String? _savedMac;
  String? _savedName;

  // En web simulamos; en Android usamos el plugin real
  bool get _isWeb => kIsWeb;

  // ── Getters públicos ───────────────────────────────────────────────────────
  BtConnectionState get state       => _state;
  List<BtDevice>    get devices     => List.unmodifiable(_devices);
  BtDevice?         get connected   => _connected;
  String?           get lastError   => _lastError;
  String?           get lastCommand => _lastCommand;
  DateTime?         get lastSent    => _lastSent;
  bool              get autoReconnect => _autoReconnect;
  int               get messagesSent  => _messagesSent;
  bool              get isConnected   => _state == BtConnectionState.connected;
  bool              get isScanning    => _state == BtConnectionState.scanning;
  String?           get savedDeviceName => _savedName;

  String get stateLabel {
    switch (_state) {
      case BtConnectionState.disabled:     return 'Bluetooth apagado';
      case BtConnectionState.enabled:      return 'Listo para conectar';
      case BtConnectionState.scanning:     return 'Buscando...';
      case BtConnectionState.connecting:   return 'Conectando...';
      case BtConnectionState.connected:    return 'Conectado';
      case BtConnectionState.disconnected: return 'Desconectado';
      case BtConnectionState.error:        return 'Error de conexión';
    }
  }

  // ── Constructor ────────────────────────────────────────────────────────────
  BluetoothSignService() {
    _loadSavedDevice();
  }

  // ── Escanear dispositivos Bluetooth ───────────────────────────────────────
  Future<void> startScan() async {
    if (_isWeb) {
      await _scanSimulated();
      return;
    }

    _state   = BtConnectionState.scanning;
    _devices = [];
    _lastError = null;
    notifyListeners();

    try {
      // Importación condicional — flutter_bluetooth_serial solo en Android
      final bt = await _getBluetoothInstance();
      if (bt == null) {
        await _scanSimulated();
        return;
      }

      // Obtener dispositivos ya vinculados primero
      final bonded = await _getBondedDevices(bt);
      _devices = bonded;
      notifyListeners();

      // Iniciar discovery de nuevos dispositivos (10 segundos)
      await _discoverDevices(bt);

    } catch (e) {
      _lastError = 'Error al escanear: $e';
      _state = BtConnectionState.enabled;
    }

    _state = BtConnectionState.enabled;
    notifyListeners();
  }

  void stopScan() {
    if (_state == BtConnectionState.scanning) {
      _state = BtConnectionState.enabled;
      notifyListeners();
    }
  }

  // ── Conectar a un dispositivo ─────────────────────────────────────────────
  Future<bool> connectTo(BtDevice device) async {
    _state     = BtConnectionState.connecting;
    _lastError = null;
    notifyListeners();

    if (_isWeb) {
      return await _connectSimulated(device);
    }

    try {
      final success = await _connectAndroid(device);
      if (success) {
        _connected = device;
        _state     = BtConnectionState.connected;
        await _saveDevice(device);
        notifyListeners();
        return true;
      } else {
        _state     = BtConnectionState.error;
        _lastError = 'No se pudo conectar a ${device.displayName}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state     = BtConnectionState.error;
      _lastError = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Desconectar ───────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    try {
      if (!_isWeb) {
        await _disconnectAndroid();
      }
    } catch (_) {}

    _connected = null;
    _state     = BtConnectionState.enabled;
    notifyListeners();
  }

  // ── Enviar comando de estado al ESP32 ─────────────────────────────────────
  Future<bool> sendStatus(SetStatus status) async {
    if (!isConnected) return false;

    final cmd   = BtCommand.fromSetStatus(status);
    final color = BtCommand.colorFromSetStatus(status);
    final label = BtCommand.labelFromSetStatus(status);

    bool ok = false;

    if (_isWeb) {
      ok = await _sendSimulated('$cmd$color$label');
    } else {
      ok = await _sendAndroid('$cmd$color$label');
    }

    if (ok) {
      _lastCommand = cmd.trim();
      _lastSent    = DateTime.now();
      _messagesSent++;
    } else {
      _lastError = 'Error al enviar comando al letrero';
      // Intentar reconectar si autoReconnect está activo
      if (_autoReconnect && _connected != null) {
        _state = BtConnectionState.disconnected;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 2));
        if (_connected != null) {
          await connectTo(_connected!);
        }
      }
    }

    notifyListeners();
    return ok;
  }

  /// Ping — verificar que el ESP32 sigue respondiendo
  Future<bool> ping() async {
    if (!isConnected) return false;

    bool ok = false;
    if (_isWeb) {
      ok = await _sendSimulated(BtCommand.ping);
    } else {
      ok = await _sendAndroid(BtCommand.ping);
    }

    if (!ok) {
      _state = BtConnectionState.disconnected;
      notifyListeners();
    }

    return ok;
  }

  void setAutoReconnect(bool v) {
    _autoReconnect = v;
    notifyListeners();
  }

  // ── Implementación Android (flutter_bluetooth_serial) ────────────────────
  // Usamos dynamic para evitar importar el plugin en web
  dynamic _btInstance;
  dynamic _btConnection;

  Future<dynamic> _getBluetoothInstance() async {
    try {
      // Evitar imports directos; usar reflection-like approach
      // En producción Android esto funciona directamente
      return null; // Se sobreescribe en implementación nativa
    } catch (_) {
      return null;
    }
  }

  Future<List<BtDevice>> _getBondedDevices(dynamic bt) async {
    // Implementación real en Android — stub aquí
    return [];
  }

  Future<void> _discoverDevices(dynamic bt) async {
    // Discovery de 10 segundos en Android
    await Future.delayed(const Duration(seconds: 2));
  }

  Future<bool> _connectAndroid(BtDevice device) async {
    try {
      // En Android real:
      // _btConnection = await FlutterBluetoothSerial.instance
      //     .connect(BluetoothDevice(address: device.address));
      // return _btConnection != null;
      await Future.delayed(const Duration(milliseconds: 800));
      return true; // Simulado hasta tener hardware
    } catch (e) {
      _lastError = 'Error conexión Android: $e';
      return false;
    }
  }

  Future<void> _disconnectAndroid() async {
    try {
      // _btConnection?.close();
      _btConnection = null;
    } catch (_) {}
  }

  Future<bool> _sendAndroid(String data) async {
    try {
      // _btConnection?.output.add(Uint8List.fromList(utf8.encode(data)));
      // await _btConnection?.output.allSent;
      await Future.delayed(const Duration(milliseconds: 50));
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Simulación (Web / demo sin hardware) ─────────────────────────────────
  Future<void> _scanSimulated() async {
    _state = BtConnectionState.scanning;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1800));

    _devices = [
      BtDevice(
        name: 'ESP32-SETSTOP',
        address: 'AA:BB:CC:DD:EE:FF',
        rssi: -45,
        isBonded: true,
      ),
      BtDevice(
        name: 'HC-05_SetLED',
        address: 'AA:BB:CC:DD:EE:01',
        rssi: -62,
        isBonded: false,
      ),
      BtDevice(
        name: 'Arduino-BT-Sign',
        address: 'AA:BB:CC:DD:EE:02',
        rssi: -78,
        isBonded: false,
      ),
    ];

    _state = BtConnectionState.enabled;
    notifyListeners();
  }

  Future<bool> _connectSimulated(BtDevice device) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    _connected = device;
    _state     = BtConnectionState.connected;
    await _saveDevice(device);
    notifyListeners();
    return true;
  }

  Future<bool> _sendSimulated(String data) async {
    await Future.delayed(const Duration(milliseconds: 40));
    return true;
  }

  // ── Persistencia del dispositivo guardado ─────────────────────────────────
  Future<void> _saveDevice(BtDevice device) async {
    _savedMac  = device.address;
    _savedName = device.displayName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bt_mac',  device.address);
    await prefs.setString('bt_name', device.displayName);
  }

  Future<void> _loadSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedMac  = prefs.getString('bt_mac');
      _savedName = prefs.getString('bt_name');
      notifyListeners();
    } catch (_) {}
  }

  Future<void> forgetDevice() async {
    _savedMac  = null;
    _savedName = null;
    _connected = null;
    _state     = BtConnectionState.enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bt_mac');
    await prefs.remove('bt_name');
    notifyListeners();
  }

  @override
  void dispose() {
    _disconnectAndroid();
    super.dispose();
  }
}
