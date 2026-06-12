import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../services/set_controller.dart';
import '../services/auth_service.dart';
import '../services/led_sign_service.dart';
import '../services/bluetooth_service.dart';
import '../utils/constants.dart';
import '../widgets/status_button.dart';
import '../widgets/timer_display.dart';
import '../widgets/scene_selector.dart';
import '../widgets/status_bar_widget.dart';
import 'login_screen.dart';
import 'led_config_screen.dart';
import 'bluetooth_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SetController>().init();
      context.read<LedSignService>().startHeartbeat();
    });
  }

  @override
  void dispose() {
    context.read<LedSignService>().stopHeartbeat();
    super.dispose();
  }

  // Getter combinado: Bluetooth tiene prioridad sobre HTTP LED
  bool get _anyDeviceConnected {
    final bt  = context.read<BluetoothSignService>();
    final led = context.read<LedSignService>();
    return bt.isConnected || led.isConnected;
  }

  Color _getStatusAccentColor(SetStatus status) {
    switch (status) {
      case SetStatus.record:
        return kRedActive;
      case SetStatus.prep:
        return kYellowActive;
      case SetStatus.libre:
        return kGreenActive;
    }
  }

  String _getStatusLabel(SetStatus status) {
    switch (status) {
      case SetStatus.record:
        return 'GRABANDO';
      case SetStatus.prep:
        return 'PREPARACIÓN';
      case SetStatus.libre:
        return 'SET LIBRE';
    }
  }

  // ─── Cambio de estado + sync LED ────────────────────────────────────────
  Future<void> _changeStatus(
      SetController ctrl, LedSignService led,
      BluetoothSignService bt, SetStatus newStatus) async {
    ctrl.changeStatus(newStatus);
    // Bluetooth tiene prioridad sobre HTTP
    if (bt.isConnected) {
      await bt.sendStatus(newStatus);
    } else if (led.config.autoSync) {
      await led.syncStatus(newStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SetController>();
    final led  = context.watch<LedSignService>();
    final bt   = context.watch<BluetoothSignService>();
    final auth = context.watch<AuthService>();
    final accentColor = _getStatusAccentColor(controller.status);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ─────────────────────────────────────────────────
              _TopBar(
                accentColor: accentColor,
                led: led,
                bt: bt,
                user: auth.currentUser,
                onMenuTap: () => _showMenu(context, auth, led, bt),
              ),
              const Divider(color: kDividerColor, height: 1),

              // ── Banner LED + BT ──────────────────────────────────────────
              _SignBanner(led: led, bt: bt),

              // ── Contenido principal ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Badge de estado
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _getStatusLabel(controller.status),
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Cronómetro
                        TimerDisplay(currentStatus: controller.status),

                        const SizedBox(height: 10),

                        // Selector de escena
                        const SceneSelector(),

                        const SizedBox(height: 28),

                        // ── Botones ────────────────────────────────────
                        _ButtonsSection(
                          controller: controller,
                          led: led,
                          bt: bt,
                          onStatusChange: _changeStatus,
                        ),

                        const SizedBox(height: 16),

                        // ── Control manual LED ─────────────────────────
                        if (!led.config.autoSync)
                          _ManualLedControl(led: led, controller: controller),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Status bar ───────────────────────────────────────────────
              const StatusBarWidget(),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(
      BuildContext context, AuthService auth,
      LedSignService led, BluetoothSignService bt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MenuSheet(auth: auth, led: led, bt: bt),
    );
  }
}

// ─── Top Bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final Color accentColor;
  final LedSignService led;
  final BluetoothSignService bt;
  final dynamic user;
  final VoidCallback onMenuTap;

  const _TopBar({
    required this.accentColor,
    required this.led,
    required this.bt,
    required this.user,
    required this.onMenuTap,
  });

  bool get _anyConnected => bt.isConnected || led.isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Avatar usuario
          GestureDetector(
            onTap: onMenuTap,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: kDividerColor,
              child: Text(
                user?.avatarInitials ?? '?',
                style: const TextStyle(
                    color: kTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Título centrado
          Expanded(
            child: Text(
              'SET-STOP',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.5,
              ),
            ),
          ),

          // Indicadores de conexión
          Row(
            children: [
              // Bluetooth indicator
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const BluetoothScreen())),
                child: _ConnectionChip(
                  label: 'BT',
                  isConnected: bt.isConnected,
                  isScanning: bt.isScanning,
                  icon: bt.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth,
                ),
              ),
              const SizedBox(width: 6),
              // Estado color dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  final String label;
  final bool isConnected;
  final bool isScanning;
  final IconData icon;

  const _ConnectionChip({
    required this.label,
    required this.isConnected,
    required this.isScanning,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? kGreenActive
        : isScanning
            ? kYellowActive
            : kTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isScanning
              ? SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: kYellowActive))
              : Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

// ─── Banner combinado LED + Bluetooth ────────────────────────────────────────
class _SignBanner extends StatelessWidget {
  final LedSignService led;
  final BluetoothSignService bt;
  const _SignBanner({required this.led, required this.bt});

  // Bluetooth tiene prioridad visual
  bool get _btActive => bt.isConnected;
  bool get _ledActive => led.isConnected;

  String get _statusLabel {
    if (_btActive) {
      switch (bt.state) {
        case BtConnectionState.connected:
          return bt.lastCommand ?? 'LETRERO CONECTADO';
        default:
          return 'LETRERO BT';
      }
    }
    if (_ledActive) return 'LETRERO: ${led.ledStatusLabel}';
    return 'LETRERO: SIN CONEXIÓN';
  }

  Color get _color {
    if (_btActive || _ledActive) {
      if (led.ledStatus == LedStatus.ocupado ||
          bt.lastCommand?.contains('OCCUPIED') == true) return kRedActive;
      if (led.ledStatus == LedStatus.preparando ||
          bt.lastCommand?.contains('PREPARING') == true) return kYellowActive;
      if (led.ledStatus == LedStatus.libre ||
          bt.lastCommand?.contains('FREE') == true) return kGreenActive;
    }
    return kTextSecondary;
  }

  IconData get _icon {
    if (_btActive) return Icons.bluetooth_connected;
    if (_ledActive) return Icons.lightbulb;
    return Icons.lightbulb_outline;
  }

  @override
  Widget build(BuildContext context) {
    final active = _btActive || _ledActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
      color: _color.withValues(alpha: active ? 0.1 : 0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, color: _color, size: 13),
          const SizedBox(width: 8),
          Text(
            _statusLabel,
            style: TextStyle(
              color: _color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
          if (led.isSyncing || bt.isScanning) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: _color),
            ),
          ],
          if (!active) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const BluetoothScreen())),
              child: Text('CONECTAR',
                  style: TextStyle(
                    color: kGreenActive,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    decoration: TextDecoration.underline,
                    decorationColor: kGreenActive,
                  )),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Botones de estado ────────────────────────────────────────────────────────
class _ButtonsSection extends StatelessWidget {
  final SetController controller;
  final LedSignService led;
  final BluetoothSignService bt;
  final Future<void> Function(SetController, LedSignService, BluetoothSignService, SetStatus)
      onStatusChange;

  const _ButtonsSection({
    required this.controller,
    required this.led,
    required this.bt,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatusButton(
          status: SetStatus.record,
          currentStatus: controller.status,
          onTap: () => onStatusChange(controller, led, bt, SetStatus.record),
        ),
        const SizedBox(height: kButtonSpacing),
        StatusButton(
          status: SetStatus.prep,
          currentStatus: controller.status,
          onTap: () => onStatusChange(controller, led, bt, SetStatus.prep),
        ),
        const SizedBox(height: kButtonSpacing),
        StatusButton(
          status: SetStatus.libre,
          currentStatus: controller.status,
          onTap: () => onStatusChange(controller, led, bt, SetStatus.libre),
        ),
      ],
    );
  }
}

// ─── Control manual LED (cuando autoSync está desactivado) ───────────────────
class _ManualLedControl extends StatelessWidget {
  final LedSignService led;
  final SetController controller;

  const _ManualLedControl({required this.led, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: kYellowActive, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Sync manual activo',
                style: TextStyle(color: kTextSecondary, fontSize: 11)),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: led.isSyncing
                  ? null
                  : () => led.syncStatus(controller.status),
              style: ElevatedButton.styleFrom(
                backgroundColor: kYellowActive,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: led.isSyncing
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('SINCRONIZAR',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menú lateral (bottom sheet) ─────────────────────────────────────────────
class _MenuSheet extends StatelessWidget {
  final AuthService auth;
  final LedSignService led;
  final BluetoothSignService bt;

  const _MenuSheet({required this.auth, required this.led, required this.bt});

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kDividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Perfil ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kDividerColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kGreenActive.withValues(alpha: 0.2),
                  child: Text(
                    user?.avatarInitials ?? '?',
                    style: TextStyle(
                        color: kGreenActive,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Usuario',
                          style: TextStyle(
                              color: kTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(user?.email ?? '',
                          style: TextStyle(
                              color: kTextSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kGreenActive.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          user?.roleLabel ?? '',
                          style: TextStyle(
                              color: kGreenActive,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Opciones ───────────────────────────────────────────────────
          _MenuItem(
            icon: Icons.bluetooth,
            label: 'Letrero Bluetooth (ESP32)',
            subtitle: bt.isConnected
                ? '✅ ${bt.connected?.displayName ?? "Conectado"}'
                : bt.savedDeviceName != null
                    ? '⏸ Último: ${bt.savedDeviceName}'
                    : 'Sin emparejar',
            iconColor: bt.isConnected ? kGreenActive : Colors.blue,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BluetoothScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.lightbulb_outline,
            label: 'Letrero por WiFi (HTTP)',
            subtitle: led.isConnected ? 'Conectado' : 'Sin conexión',
            iconColor: kYellowActive,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LedConfigScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.history_outlined,
            label: 'Historial de sesiones',
            subtitle: 'Próximamente',
            iconColor: kTextSecondary,
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Preferencias',
            subtitle: 'Próximamente',
            iconColor: kTextSecondary,
            onTap: () {},
          ),

          const Divider(color: kDividerColor, height: 24),

          // ── Cerrar sesión ──────────────────────────────────────────────
          _MenuItem(
            icon: Icons.logout,
            label: 'Cerrar sesión',
            subtitle: '',
            iconColor: kRedActive,
            onTap: () async {
              Navigator.pop(context);
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                    (route) => false);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(label,
          style: TextStyle(color: kTextColor, fontSize: 13)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: TextStyle(color: kTextSecondary, fontSize: 11))
          : null,
      trailing: Icon(Icons.chevron_right, color: kTextSecondary, size: 18),
      onTap: onTap,
    );
  }
}
