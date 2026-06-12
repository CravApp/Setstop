import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../utils/constants.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bt = context.read<BluetoothSignService>();
      if (!bt.isConnected && bt.devices.isEmpty) {
        bt.startScan();
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothSignService>();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: kTextSecondary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'LETRERO BLUETOOTH',
          style: TextStyle(
            color: kTextColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        actions: [
          if (bt.isConnected)
            IconButton(
              icon: const Icon(Icons.link_off, color: kRedActive, size: 22),
              tooltip: 'Desconectar',
              onPressed: () async {
                await bt.disconnect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Letrero desconectado'),
                    backgroundColor: kSurfaceColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ));
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Panel de estado principal ──────────────────────────────────
            _StatusPanel(bt: bt, pulseAnim: _pulseAnim),

            // ── Estadísticas si está conectado ────────────────────────────
            if (bt.isConnected) _StatsRow(bt: bt),

            const SizedBox(height: 8),

            // ── Sección dispositivos ───────────────────────────────────────
            Expanded(
              child: _DeviceSection(bt: bt),
            ),

            // ── Botón de scan ──────────────────────────────────────────────
            _ScanButton(bt: bt),

            // ── Guía Arduino/ESP32 ─────────────────────────────────────────
            _ArduinoGuide(),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Panel de estado ──────────────────────────────────────────────────────────
class _StatusPanel extends StatelessWidget {
  final BluetoothSignService bt;
  final Animation<double> pulseAnim;

  const _StatusPanel({required this.bt, required this.pulseAnim});

  Color get _stateColor {
    switch (bt.state) {
      case BtConnectionState.connected:
        return kGreenActive;
      case BtConnectionState.connecting:
      case BtConnectionState.scanning:
        return kYellowActive;
      case BtConnectionState.error:
      case BtConnectionState.disconnected:
        return kRedActive;
      default:
        return kTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _stateColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _stateColor.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icono animado ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: (bt.isScanning || bt.state == BtConnectionState.connecting)
                  ? pulseAnim.value
                  : 1.0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _stateColor.withValues(alpha: 0.15),
                  border: Border.all(color: _stateColor, width: 2),
                ),
                child: Icon(
                  bt.isConnected
                      ? Icons.bluetooth_connected
                      : bt.isScanning
                          ? Icons.bluetooth_searching
                          : Icons.bluetooth,
                  color: _stateColor,
                  size: 28,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // ── Info ───────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bt.isConnected
                      ? bt.connected!.displayName
                      : 'Letrero LED 3D',
                  style: const TextStyle(
                    color: kTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _stateColor,
                        boxShadow: bt.isConnected
                            ? [
                                BoxShadow(
                                  color: _stateColor.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bt.stateLabel,
                      style: TextStyle(color: _stateColor, fontSize: 12),
                    ),
                  ],
                ),
                if (bt.isConnected && bt.connected != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    bt.connected!.address,
                    style: TextStyle(
                        color: kTextSecondary,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                ],
                if (bt.savedDeviceName != null && !bt.isConnected) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Último: ${bt.savedDeviceName}',
                    style: TextStyle(color: kTextSecondary, fontSize: 10),
                  ),
                ],
                if (bt.lastError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    bt.lastError!,
                    style: TextStyle(color: kRedActive, fontSize: 10),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),

          // ── Test ping ──────────────────────────────────────────────────
          if (bt.isConnected)
            IconButton(
              icon: const Icon(Icons.radar, color: kGreenActive, size: 22),
              tooltip: 'Hacer ping',
              onPressed: () async {
                final ok = await bt.ping();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        ok ? '✅ Letrero respondió OK' : '❌ Sin respuesta'),
                    backgroundColor: ok ? kGreenActive : kRedActive,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ));
                }
              },
            ),
        ],
      ),
    );
  }
}

// ─── Estadísticas de la sesión ─────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final BluetoothSignService bt;
  const _StatsRow({required this.bt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.send_outlined,
            label: '${bt.messagesSent} comandos',
            color: kGreenActive,
          ),
          const SizedBox(width: 8),
          if (bt.lastSent != null)
            _StatChip(
              icon: Icons.schedule,
              label: 'Último: ${_fmt(bt.lastSent!)}',
              color: kTextSecondary,
            ),
          const SizedBox(width: 8),
          if (bt.lastCommand != null)
            _StatChip(
              icon: Icons.code,
              label: bt.lastCommand!,
              color: kYellowActive,
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Sección de dispositivos encontrados ─────────────────────────────────────
class _DeviceSection extends StatelessWidget {
  final BluetoothSignService bt;
  const _DeviceSection({required this.bt});

  @override
  Widget build(BuildContext context) {
    if (bt.isScanning && bt.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kYellowActive),
            ),
            const SizedBox(height: 16),
            Text('Buscando dispositivos Bluetooth...',
                style: TextStyle(color: kTextSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Asegúrate que el ESP32 esté encendido',
                style: TextStyle(color: kTextSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    if (bt.devices.isEmpty && !bt.isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, color: kTextSecondary, size: 48),
            const SizedBox(height: 16),
            Text('No se encontraron dispositivos',
                style: TextStyle(color: kTextSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Presiona "BUSCAR DISPOSITIVOS" para escanear',
                style: TextStyle(color: kTextSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    // Separar bonded de nuevos
    final bonded  = bt.devices.where((d) => d.isBonded).toList();
    final newDevs = bt.devices.where((d) => !d.isBonded).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (bonded.isNotEmpty) ...[
          _ListHeader('DISPOSITIVOS VINCULADOS', Icons.link),
          ...bonded.map((d) => _DeviceTile(device: d, bt: bt)),
          const SizedBox(height: 12),
        ],
        if (newDevs.isNotEmpty) ...[
          _ListHeader('DISPOSITIVOS ENCONTRADOS', Icons.search),
          ...newDevs.map((d) => _DeviceTile(device: d, bt: bt)),
        ],
        if (bt.isScanning && bt.devices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kYellowActive),
                ),
                const SizedBox(width: 10),
                Text('Buscando más dispositivos...',
                    style: TextStyle(color: kTextSecondary, fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ListHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, color: kTextSecondary, size: 12),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  color: kTextSecondary,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Tile de dispositivo ─────────────────────────────────────────────────────
class _DeviceTile extends StatelessWidget {
  final BtDevice device;
  final BluetoothSignService bt;

  const _DeviceTile({required this.device, required this.bt});

  bool get _isConnected =>
      bt.isConnected && bt.connected?.address == device.address;

  Color get _signalColor {
    if (device.rssi >= -60) return kGreenActive;
    if (device.rssi >= -75) return kYellowActive;
    return kRedActive;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _isConnected
            ? kGreenActive.withValues(alpha: 0.08)
            : kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isConnected ? kGreenActive : kDividerColor,
          width: _isConnected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isConnected
                ? kGreenActive.withValues(alpha: 0.2)
                : kDividerColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isEsp32(device.name)
                ? Icons.developer_board
                : Icons.bluetooth,
            color: _isConnected ? kGreenActive : kTextSecondary,
            size: 22,
          ),
        ),
        title: Text(
          device.displayName,
          style: TextStyle(
            color: _isConnected ? kGreenActive : kTextColor,
            fontWeight:
                _isConnected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.address,
                style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 10,
                    fontFamily: 'monospace')),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt,
                    color: _signalColor, size: 12),
                const SizedBox(width: 4),
                Text('${device.signalStrength} (${device.rssi} dBm)',
                    style: TextStyle(color: _signalColor, fontSize: 10)),
                if (device.isBonded) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.verified, color: kGreenActive, size: 11),
                  const SizedBox(width: 2),
                  Text('Vinculado',
                      style: TextStyle(color: kGreenActive, fontSize: 10)),
                ],
              ],
            ),
          ],
        ),
        trailing: _isConnected
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kGreenActive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('CONECTADO',
                    style: TextStyle(
                        color: kGreenActive,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              )
            : bt.state == BtConnectionState.connecting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kYellowActive))
                : Icon(Icons.link, color: kTextSecondary, size: 20),
        onTap: _isConnected
            ? null
            : () => _connectTo(context, device),
      ),
    );
  }

  bool _isEsp32(String name) {
    final n = name.toLowerCase();
    return n.contains('esp') ||
        n.contains('arduino') ||
        n.contains('hc-05') ||
        n.contains('hc-06') ||
        n.contains('set');
  }

  Future<void> _connectTo(BuildContext context, BtDevice device) async {
    HapticFeedback.mediumImpact();
    final ok = await bt.connectTo(device);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '✅ Conectado a ${device.displayName}'
            : '❌ ${bt.lastError ?? "Error al conectar"}'),
        backgroundColor: ok ? kGreenActive : kRedActive,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }
}

// ─── Botón de scan ────────────────────────────────────────────────────────────
class _ScanButton extends StatelessWidget {
  final BluetoothSignService bt;
  const _ScanButton({required this.bt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: bt.isScanning || bt.state == BtConnectionState.connecting
              ? null
              : () => bt.startScan(),
          icon: bt.isScanning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Icon(Icons.bluetooth_searching, size: 20),
          label: Text(bt.isScanning ? 'BUSCANDO...' : 'BUSCAR DISPOSITIVOS',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                bt.isScanning ? kYellowActive.withValues(alpha: 0.4) : kYellowActive,
            foregroundColor: Colors.black,
            disabledBackgroundColor: kYellowActive.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

// ─── Guía Arduino/ESP32 ───────────────────────────────────────────────────────
class _ArduinoGuide extends StatefulWidget {
  @override
  State<_ArduinoGuide> createState() => _ArduinoGuideState();
}

class _ArduinoGuideState extends State<_ArduinoGuide> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kGreenActive.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: kGreenActive.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.developer_board,
                      color: kGreenActive, size: 14),
                  const SizedBox(width: 8),
                  Text('GUÍA: CÓDIGO ARDUINO/ESP32',
                      style: TextStyle(
                          color: kGreenActive,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: kGreenActive,
                    size: 18,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                _CodeBlock(
                  title: 'Pines recomendados ESP32:',
                  code: '''
LED ROJO    → GPIO 25
LED AMARILLO→ GPIO 26  
LED VERDE   → GPIO 27
Bluetooth   → ESP32 nativo (BT Classic)
''',
                ),
                const SizedBox(height: 8),
                _CodeBlock(
                  title: 'Protocolo de comandos (Serial BT):',
                  code: '''
SET:OCCUPIED   → Enciende LED Rojo (OCUPADO)
SET:PREPARING  → Enciende LED Amarillo (PREPARANDO)
SET:FREE       → Enciende LED Verde (LIBRE)
COLOR:RRGGBB   → Color personalizado en hex
TEXT:MENSAJE   → Texto para display LCD/LED
PING           → Responde "PONG" (keep-alive)
''',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kYellowActive.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: kYellowActive.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: kYellowActive, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El firmware completo para ESP32 está disponible en la sección de documentación de la app.',
                          style: TextStyle(
                              color: kYellowActive, fontSize: 10, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String title;
  final String code;
  const _CodeBlock({required this.title, required this.code});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: kTextSecondary, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code.trim(),
            style: const TextStyle(
              color: kGreenActive,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
