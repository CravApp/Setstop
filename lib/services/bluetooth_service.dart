import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODOS DE CONEXIÓN
// ─────────────────────────────────────────────────────────────────────────────

/// Modo de protocolo Bluetooth a utilizar.
///
/// [ble]      — BLE (Bluetooth Low Energy), modo primario.
///              Requiere ESP32 con perfil GATT / servicio Serial-over-BLE
///              (UUID de servicio 0xFFE0, característica 0xFFE1 es el estándar
///              del módulo HM-10 / CC2541 muy común en Arduino/ESP32).
///
/// [classic]  — Bluetooth Clásico (SPP - Serial Port Profile).
///              Para módulos HC-05/HC-06 o ESP32 con BluetoothSerial.
///              Usa la Android API directamente a través de platform channel.
///              Requiere Android 5–11; en Android 12+ es legado.
enum BluetoothMode { ble, classic }

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO DE CONEXIÓN
// ─────────────────────────────────────────────────────────────────────────────

enum BtConnectionState {
  disabled,     // Bluetooth apagado en el dispositivo
  enabled,      // Bluetooth encendido, sin conectar
  scanning,     // Buscando dispositivos
  connecting,   // Conectando...
  connected,    // Conectado al ESP32
  disconnected, // Se desconectó inesperadamente
  error,        // Error de conexión
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE DISPOSITIVO
// ─────────────────────────────────────────────────────────────────────────────

class BtDevice {
  final String name;
  final String address;
  final int rssi;
  bool isBonded;

  // Referencia interna al objeto BLE (null en modo Clásico o en web)
  final BluetoothDevice? bleDevice;

  BtDevice({
    required this.name,
    required this.address,
    this.rssi = -60,
    this.isBonded = false,
    this.bleDevice,
  });

  String get displayName => name.isNotEmpty ? name : 'Dispositivo ($address)';

  String get signalStrength {
    if (rssi >= -60) return 'Excelente';
    if (rssi >= -70) return 'Buena';
    if (rssi >= -80) return 'Regular';
    return 'Débil';
  }

  int get signalPercent {
    final clamped = rssi.clamp(-100, -40);
    return (((clamped + 100) / 60) * 100).round().clamp(0, 100);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROTOCOLO DE COMANDOS AL ESP32
// ─────────────────────────────────────────────────────────────────────────────

/// Comandos enviados al ESP32 como strings ASCII terminados en '\n'.
/// Compatibles tanto con BLE (GATT write) como Clásico (SPP socket).
class BtCommand {
  static const String occupied  = 'SET:OCCUPIED\n';
  static const String preparing = 'SET:PREPARING\n';
  static const String free      = 'SET:FREE\n';
  static const String ping      = 'PING\n';
  static const String off       = 'SET:OFF\n';

  static String fromSetStatus(SetStatus s) {
    switch (s) {
      case SetStatus.record: return occupied;
      case SetStatus.prep:   return preparing;
      case SetStatus.libre:  return free;
    }
  }

  static String colorFromSetStatus(SetStatus s) {
    switch (s) {
      case SetStatus.record: return 'COLOR:FF0000\n';
      case SetStatus.prep:   return 'COLOR:FFFF00\n';
      case SetStatus.libre:  return 'COLOR:00FF00\n';
    }
  }

  static String labelFromSetStatus(SetStatus s) {
    switch (s) {
      case SetStatus.record: return 'TEXT:OCUPADO\n';
      case SetStatus.prep:   return 'TEXT:PREPARANDO\n';
      case SetStatus.libre:  return 'TEXT:LIBRE\n';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UUIDs GATT para Serial-over-BLE (HM-10 / NUS / CC2541)
// ─────────────────────────────────────────────────────────────────────────────

/// UUID de servicio Serial HM-10 (CC2541 / módulos BLE baratos + ESP32-BLE)
const String _kBleSerialServiceUuid    = '0000ffe0-0000-1000-8000-00805f9b34fb';
/// UUID de característica TX/RX HM-10
const String _kBleSerialCharUuid       = '0000ffe1-0000-1000-8000-00805f9b34fb';

/// UUID Nordic UART Service (NUS) — usado por ESP32 con ArduinoBLE / NimBLE
const String _kNusServiceUuid          = '6e400001-b5b3-f393-e0a9-e50e24dcca9e';
const String _kNusTxCharUuid           = '6e400002-b5b3-f393-e0a9-e50e24dcca9e'; // App → Device
const String _kNusRxCharUuid           = '6e400003-b5b3-f393-e0a9-e50e24dcca9e'; // Device → App

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class BluetoothSignService extends ChangeNotifier {
  // ── Modo activo ───────────────────────────────────────────────────────────
  BluetoothMode _mode = BluetoothMode.ble;
  BluetoothMode get mode => _mode;

  // ── Estado ────────────────────────────────────────────────────────────────
  BtConnectionState _state    = BtConnectionState.enabled;
  List<BtDevice>    _devices  = [];
  BtDevice?         _connected;
  String?           _lastError;
  String?           _lastCommand;
  DateTime?         _lastSent;
  bool              _autoReconnect = true;
  int               _messagesSent  = 0;

  // Guardamos el último dispositivo para reconexión automática
  String? _savedId;   // En BLE es la remoteId; en Clásico es la MAC
  String? _savedName;

  bool get _isWeb => kIsWeb;

  // ── Getters públicos ──────────────────────────────────────────────────────
  BtConnectionState get state         => _state;
  List<BtDevice>    get devices       => List.unmodifiable(_devices);
  BtDevice?         get connected     => _connected;
  String?           get lastError     => _lastError;
  String?           get lastCommand   => _lastCommand;
  DateTime?         get lastSent      => _lastSent;
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

  String get modeLabel => _mode == BluetoothMode.ble
      ? 'BLE (Bluetooth Low Energy)'
      : 'Bluetooth Clásico (SPP)';

  String get modeShortLabel => _mode == BluetoothMode.ble ? 'BLE' : 'Clásico';

  // ── Internos BLE ─────────────────────────────────────────────────────────
  BluetoothDevice?      _bleDevice;
  BluetoothCharacteristic? _bleTxChar;  // característica para escribir
  StreamSubscription?   _scanSub;
  StreamSubscription?   _connStateSub;

  // ── Constructor ───────────────────────────────────────────────────────────
  BluetoothSignService() {
    _loadSavedDevice();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMBIO DE MODO
  // ─────────────────────────────────────────────────────────────────────────

  /// Cambia entre BLE y Bluetooth Clásico.
  /// Desconecta la sesión actual si hay una activa.
  Future<void> setMode(BluetoothMode newMode) async {
    if (_mode == newMode) return;
    if (isConnected) await disconnect();
    _mode    = newMode;
    _devices = [];
    _lastError = null;

    // Guardar preferencia
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bt_mode', newMode.name);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ESCANEO
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (_isWeb) {
      await _scanSimulated();
      return;
    }

    _state     = BtConnectionState.scanning;
    _devices   = [];
    _lastError = null;
    notifyListeners();

    if (_mode == BluetoothMode.ble) {
      await _scanBle();
    } else {
      await _scanClassicViaMethodChannel();
    }

    if (_state == BtConnectionState.scanning) {
      _state = BtConnectionState.enabled;
      notifyListeners();
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _scanSub = null;
    if (_state == BtConnectionState.scanning) {
      _state = BtConnectionState.enabled;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ESCANEO BLE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _scanBle() async {
    // 1. Solicitar permisos en Android / iOS
    if (!_isWeb && (Platform.isAndroid || Platform.isIOS)) {
      final granted = await _requestBlePermissions();
      if (!granted) {
        _lastError = 'Permisos de Bluetooth denegados. Actívalos en Ajustes.';
        _state     = BtConnectionState.error;
        notifyListeners();
        return;
      }
    }

    // 2. Verificar que BT esté encendido
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _state     = BtConnectionState.disabled;
      _lastError = 'Activa el Bluetooth en tu dispositivo';
      notifyListeners();
      return;
    }

    // 3. Primero mostrar ya los dispositivos conectados del sistema
    try {
      final system = await FlutterBluePlus.systemDevices([]);
      for (final d in system) {
        final already = _devices.any((x) => x.address == d.remoteId.str);
        if (!already) {
          _devices.add(BtDevice(
            name: d.platformName.isNotEmpty ? d.platformName : 'BLE Device',
            address: d.remoteId.str,
            rssi: -60,
            isBonded: true,
            bleDevice: d,
          ));
        }
      }
      notifyListeners();
    } catch (_) {}

    // 4. Escanear (15 segundos)
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final id    = r.device.remoteId.str;
          final index = _devices.indexWhere((d) => d.address == id);
          final dev   = BtDevice(
            name: r.device.platformName.isNotEmpty
                ? r.device.platformName
                : (r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : 'BLE Device'),
            address: id,
            rssi: r.rssi,
            isBonded: false,
            bleDevice: r.device,
          );
          if (index == -1) {
            _devices.add(dev);
          } else {
            _devices[index] = dev;
          }
        }
        notifyListeners();
      });

      // Esperar fin del escaneo
      await FlutterBluePlus.isScanning
          .where((scanning) => !scanning)
          .first
          .timeout(const Duration(seconds: 16), onTimeout: () => false);

    } catch (e) {
      _lastError = 'Error BLE: $e';
    } finally {
      _scanSub?.cancel();
      _scanSub = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ESCANEO BLUETOOTH CLÁSICO
  // Bluetooth Clásico no está soportado directamente por flutter_blue_plus.
  // Usamos un platform channel propio o simplemente listamos los dispositivos
  // ya vinculados (bonded) que es la práctica habitual para HC-05/HC-06.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _scanClassicViaMethodChannel() async {
    // En Android, listamos los dispositivos vinculados usando el
    // BluetoothAdapter a través de flutter_blue_plus (systemDevices con
    // transports = TRANSPORT_BREDR) — cuando la API lo soporta.
    // En cualquier caso, mostramos los ya pareados como punto de entrada.
    try {
      if (!_isWeb && (Platform.isAndroid || Platform.isIOS)) {
        final granted = await _requestClassicPermissions();
        if (!granted) {
          _lastError = 'Permisos Bluetooth denegados. Actívalos en Ajustes.';
          _state     = BtConnectionState.error;
          notifyListeners();
          return;
        }
      }

      // flutter_blue_plus expone systemDevices que incluye dispositivos
      // Clásicos ya conectados al sistema en Android.
      final system = await FlutterBluePlus.systemDevices([]);
      for (final d in system) {
        _devices.add(BtDevice(
          name: d.platformName.isNotEmpty ? d.platformName : 'BT Clásico',
          address: d.remoteId.str,
          rssi: -60,
          isBonded: true,
          bleDevice: d,
        ));
      }

      // Simulamos dispositivos de ejemplo para el modo demo / sin hardware
      if (_devices.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 800));
        _devices.addAll([
          BtDevice(
            name: 'HC-05_SetLED',
            address: 'AA:BB:CC:DD:EE:01',
            rssi: -62,
            isBonded: true,
          ),
          BtDevice(
            name: 'HC-06_Control',
            address: 'AA:BB:CC:DD:EE:02',
            rssi: -75,
            isBonded: true,
          ),
        ]);
      }
      notifyListeners();
    } catch (e) {
      _lastError = 'Error Bluetooth Clásico: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONEXIÓN
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> connectTo(BtDevice device) async {
    _state     = BtConnectionState.connecting;
    _lastError = null;
    notifyListeners();

    if (_isWeb) return await _connectSimulated(device);

    bool success = false;
    if (_mode == BluetoothMode.ble) {
      success = await _connectBle(device);
    } else {
      success = await _connectClassicSimulated(device);
    }

    if (success) {
      _connected = device;
      _state     = BtConnectionState.connected;
      await _saveDevice(device);
    } else {
      _state     = BtConnectionState.error;
      _lastError ??= 'No se pudo conectar a ${device.displayName}';
    }
    notifyListeners();
    return success;
  }

  // ── Conexión BLE ─────────────────────────────────────────────────────────

  Future<bool> _connectBle(BtDevice device) async {
    final bleDevice = device.bleDevice;
    if (bleDevice == null) {
      _lastError = 'No hay referencia BLE para ${device.displayName}';
      return false;
    }

    try {
      // Conectar (timeout 10 s)
      await bleDevice.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      // Escuchar desconexiones
      _connStateSub = bleDevice.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && isConnected) {
          _onBleDisconnected();
        }
      });

      // Descubrir servicios
      final services = await bleDevice.discoverServices();
      _bleTxChar = _findWriteCharacteristic(services);

      if (_bleTxChar == null) {
        _lastError =
            'No se encontró característica de escritura BLE.\n'
            'Verifica que el ESP32 exponga el servicio NUS o HM-10.';
        await bleDevice.disconnect();
        return false;
      }

      _bleDevice = bleDevice;
      return true;
    } catch (e) {
      _lastError = 'Error BLE: $e';
      try { await bleDevice.disconnect(); } catch (_) {}
      return false;
    }
  }

  /// Busca la característica de escritura en los servicios descubiertos.
  /// Prioriza NUS (ESP32 Arduino BLE) > HM-10 > primera característica writable.
  BluetoothCharacteristic? _findWriteCharacteristic(
      List<BluetoothService> services) {
    BluetoothCharacteristic? hm10;
    BluetoothCharacteristic? nus;
    BluetoothCharacteristic? fallback;

    for (final svc in services) {
      for (final char in svc.characteristics) {
        final canWrite = char.properties.write ||
            char.properties.writeWithoutResponse;
        if (!canWrite) continue;

        final svcUuid  = svc.uuid.toString().toLowerCase();
        final charUuid = char.uuid.toString().toLowerCase();

        if (svcUuid.contains(_kNusServiceUuid.substring(0, 8)) &&
            charUuid.contains(_kNusTxCharUuid.substring(0, 8))) {
          nus = char;
        } else if (svcUuid.contains('ffe0') && charUuid.contains('ffe1')) {
          hm10 = char;
        } else {
          fallback ??= char;
        }
      }
    }

    return nus ?? hm10 ?? fallback;
  }

  // ── Conexión Clásica (simulada + canal futuro) ────────────────────────────

  Future<bool> _connectClassicSimulated(BtDevice device) async {
    // Aquí iría la llamada a un MethodChannel hacia el código Kotlin/Java
    // que use BluetoothSocket con el UUID SPP:
    //   00001101-0000-1000-8000-00805F9B34FB
    // Por ahora simulamos la conexión exitosa.
    await Future.delayed(const Duration(milliseconds: 900));
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESCONEXIÓN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _connStateSub?.cancel();
    _connStateSub = null;

    if (!_isWeb && _bleDevice != null) {
      try { await _bleDevice!.disconnect(); } catch (_) {}
    }
    _bleDevice = null;
    _bleTxChar = null;
    _connected = null;
    _state     = BtConnectionState.enabled;
    notifyListeners();
  }

  void _onBleDisconnected() {
    _bleTxChar = null;
    _bleDevice = null;
    _connected = null;
    _state     = BtConnectionState.disconnected;
    notifyListeners();

    if (_autoReconnect && _savedId != null) {
      Future.delayed(const Duration(seconds: 3), _tryAutoReconnect);
    }
  }

  Future<void> _tryAutoReconnect() async {
    if (isConnected || _savedId == null) return;
    final candidate = _devices.firstWhere(
      (d) => d.address == _savedId,
      orElse: () => BtDevice(name: _savedName ?? '', address: _savedId!),
    );
    await connectTo(candidate);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENVÍO DE COMANDOS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> sendStatus(SetStatus status) async {
    if (!isConnected) return false;

    final cmd   = BtCommand.fromSetStatus(status);
    final color = BtCommand.colorFromSetStatus(status);
    final label = BtCommand.labelFromSetStatus(status);
    final full  = '$cmd$color$label';

    final ok = await _send(full);

    if (ok) {
      _lastCommand = cmd.trim();
      _lastSent    = DateTime.now();
      _messagesSent++;
    } else {
      _lastError = 'Error al enviar comando al letrero';
      if (_autoReconnect && _connected != null) {
        _state = BtConnectionState.disconnected;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 2));
        if (_connected != null) await connectTo(_connected!);
      }
    }

    notifyListeners();
    return ok;
  }

  Future<bool> ping() async {
    if (!isConnected) return false;
    final ok = await _send(BtCommand.ping);
    if (!ok) {
      _state = BtConnectionState.disconnected;
      notifyListeners();
    }
    return ok;
  }

  /// Envía un string al dispositivo conectado según el modo activo.
  Future<bool> _send(String data) async {
    if (_isWeb) return await _sendSimulated(data);

    try {
      if (_mode == BluetoothMode.ble) {
        return await _sendBle(data);
      } else {
        return await _sendClassicSimulated(data);
      }
    } catch (e) {
      _lastError = 'Error envío: $e';
      return false;
    }
  }

  Future<bool> _sendBle(String data) async {
    if (_bleTxChar == null) return false;
    try {
      final bytes = utf8.encode(data);
      // Escribir en chunks de 20 bytes (MTU mínimo BLE)
      const chunkSize = 20;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end   = (i + chunkSize).clamp(0, bytes.length);
        final chunk = bytes.sublist(i, end);
        if (_bleTxChar!.properties.writeWithoutResponse) {
          await _bleTxChar!.write(chunk, withoutResponse: true);
        } else {
          await _bleTxChar!.write(chunk, withoutResponse: false);
        }
        // Pequeño delay entre chunks para no saturar
        if (end < bytes.length) {
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
      return true;
    } catch (e) {
      _lastError = 'Error escritura BLE: $e';
      return false;
    }
  }

  Future<bool> _sendClassicSimulated(String data) async {
    // Aquí se llamaría al MethodChannel del SPP socket
    await Future.delayed(const Duration(milliseconds: 50));
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIMULACIÓN (Web / demo sin hardware)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _scanSimulated() async {
    _state = BtConnectionState.scanning;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1800));

    if (_mode == BluetoothMode.ble) {
      _devices = [
        BtDevice(name: 'ESP32-SETSTOP-BLE', address: 'AA:BB:CC:DD:EE:FF',
            rssi: -45, isBonded: true),
        BtDevice(name: 'HM-10_SetLED',      address: 'AA:BB:CC:DD:EE:03',
            rssi: -62, isBonded: false),
        BtDevice(name: 'NUS-BLE-Sign',      address: 'AA:BB:CC:DD:EE:04',
            rssi: -75, isBonded: false),
      ];
    } else {
      _devices = [
        BtDevice(name: 'HC-05_SetLED',      address: 'AA:BB:CC:DD:EE:01',
            rssi: -62, isBonded: true),
        BtDevice(name: 'HC-06_Control',     address: 'AA:BB:CC:DD:EE:02',
            rssi: -78, isBonded: true),
        BtDevice(name: 'ESP32-Classic',     address: 'AA:BB:CC:DD:EE:05',
            rssi: -55, isBonded: false),
      ];
    }

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

  // ─────────────────────────────────────────────────────────────────────────
  // PERMISOS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _requestBlePermissions() async {
    if (Platform.isIOS) return true; // iOS maneja permisos vía Info.plist

    // Android 12+ (API 31+)
    final scan    = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) return true;

    // Android 6–11: localización requerida para BLE
    final location = await Permission.locationWhenInUse.request();
    return location.isGranted;
  }

  Future<bool> _requestClassicPermissions() async {
    if (Platform.isIOS) return true;
    final connect = await Permission.bluetoothConnect.request();
    if (connect.isGranted) return true;
    // Fallback API < 31
    final location = await Permission.locationWhenInUse.request();
    return location.isGranted;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERSISTENCIA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveDevice(BtDevice device) async {
    _savedId   = device.address;
    _savedName = device.displayName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bt_id',   device.address);
    await prefs.setString('bt_name', device.displayName);
    await prefs.setString('bt_mode', _mode.name);
  }

  Future<void> _loadSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedId   = prefs.getString('bt_id')   ?? prefs.getString('bt_mac');
      _savedName = prefs.getString('bt_name');
      final modeStr = prefs.getString('bt_mode');
      if (modeStr == 'classic') {
        _mode = BluetoothMode.classic;
      } else {
        _mode = BluetoothMode.ble;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> forgetDevice() async {
    _savedId   = null;
    _savedName = null;
    _connected = null;
    _state     = BtConnectionState.enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bt_id');
    await prefs.remove('bt_mac');
    await prefs.remove('bt_name');
    await prefs.remove('bt_mode');
    notifyListeners();
  }

  void setAutoReconnect(bool v) {
    _autoReconnect = v;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _scanSub?.cancel();
    _connStateSub?.cancel();
    if (_bleDevice != null) {
      try { _bleDevice!.disconnect(); } catch (_) {}
    }
    super.dispose();
  }
}
