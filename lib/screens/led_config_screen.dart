import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/led_sign_service.dart';
import '../utils/constants.dart';

class LedConfigScreen extends StatefulWidget {
  const LedConfigScreen({super.key});

  @override
  State<LedConfigScreen> createState() => _LedConfigScreenState();
}

class _LedConfigScreenState extends State<LedConfigScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  LedProtocol _protocol = LedProtocol.http;
  bool _autoSync = true;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<LedSignService>().config;
    _hostCtrl.text = cfg.host;
    _portCtrl.text = cfg.port.toString();
    _nameCtrl.text = cfg.deviceName;
    _protocol = cfg.protocol;
    _autoSync = cfg.autoSync;
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final led = context.read<LedSignService>();
    await led.updateConfig(LedSignConfig(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 80,
      protocol: _protocol,
      deviceName: _nameCtrl.text.trim(),
      autoSync: _autoSync,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Configuración guardada'),
        backgroundColor: kGreenActive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  Future<void> _testConnection() async {
    final led = context.read<LedSignService>();
    await led.updateConfig(LedSignConfig(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 80,
      protocol: _protocol,
      deviceName: _nameCtrl.text.trim(),
      autoSync: _autoSync,
    ));
    final ok = await led.testConnection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '✅ Letrero conectado correctamente'
            : '❌ ${led.lastError ?? "No se pudo conectar"}'),
        backgroundColor: ok ? kGreenActive : kRedActive,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final led = context.watch<LedSignService>();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: kTextSecondary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('LETRERO LED',
            style: TextStyle(
                color: kTextColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 3)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Estado actual del letrero ──────────────────────────────
              _LedStatusCard(led: led),
              const SizedBox(height: 28),

              // ── Sección: Dispositivo ───────────────────────────────────
              _SectionHeader(
                  icon: Icons.devices_outlined, title: 'DISPOSITIVO'),
              const SizedBox(height: 12),

              _ConfigField(
                controller: _nameCtrl,
                label: 'Nombre del letrero',
                hint: 'Letrero Set A',
                icon: Icons.label_outline,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _ConfigField(
                      controller: _hostCtrl,
                      label: 'IP del letrero',
                      hint: '192.168.1.100',
                      icon: Icons.router_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _ConfigField(
                      controller: _portCtrl,
                      label: 'Puerto',
                      hint: '80',
                      icon: Icons.settings_ethernet,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Sección: Protocolo ─────────────────────────────────────
              _SectionHeader(
                  icon: Icons.wifi_tethering_outlined,
                  title: 'PROTOCOLO DE COMUNICACIÓN'),
              const SizedBox(height: 12),

              _ProtocolSelector(
                selected: _protocol,
                onChanged: (p) {
                  setState(() {
                    _protocol = p;
                    _portCtrl.text = p == LedProtocol.mqtt ? '1883' : '80';
                  });
                },
              ),
              const SizedBox(height: 24),

              // ── Auto-sync ──────────────────────────────────────────────
              _SectionHeader(
                  icon: Icons.sync_outlined, title: 'SINCRONIZACIÓN'),
              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kDividerColor),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Sincronización automática',
                      style:
                          TextStyle(color: kTextColor, fontSize: 13)),
                  subtitle: Text(
                      'El letrero cambia al mismo tiempo que la app',
                      style:
                          TextStyle(color: kTextSecondary, fontSize: 11)),
                  value: _autoSync,
                  onChanged: (v) => setState(() => _autoSync = v),
                  activeThumbColor: kGreenActive,
                ),
              ),
              const SizedBox(height: 24),

              // ── Guía de conexión ───────────────────────────────────────
              _ConnectionGuide(protocol: _protocol),
              const SizedBox(height: 28),

              // ── Botones ────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: led.isSyncing ? null : _testConnection,
                      icon: led.isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: kGreenActive))
                          : const Icon(Icons.wifi_find_outlined,
                              size: 18),
                      label: const Text('PROBAR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kGreenActive,
                        side: BorderSide(color: kGreenActive),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveConfig,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('GUARDAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenActive,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets ───────────────────────────────────────────────────────────────────

class _LedStatusCard extends StatelessWidget {
  final LedSignService led;
  const _LedStatusCard({required this.led});

  Color get _statusColor {
    switch (led.ledStatus) {
      case LedStatus.ocupado:
        return kRedActive;
      case LedStatus.preparando:
        return kYellowActive;
      case LedStatus.libre:
        return kGreenActive;
      case LedStatus.desconectado:
        return kTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: led.isConnected
              ? _statusColor.withValues(alpha: 0.4)
              : kDividerColor,
        ),
      ),
      child: Row(
        children: [
          // LED indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor.withValues(alpha: 0.15),
              border: Border.all(color: _statusColor, width: 2),
            ),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor,
                  boxShadow: led.isConnected
                      ? [
                          BoxShadow(
                              color: _statusColor.withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 2)
                        ]
                      : [],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  led.config.deviceName,
                  style: TextStyle(
                      color: kTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: led.isConnected ? kGreenActive : kRedActive,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      led.isConnected
                          ? '${led.config.host}:${led.config.port}'
                          : 'Sin conexión',
                      style: TextStyle(color: kTextSecondary, fontSize: 11),
                    ),
                  ],
                ),
                if (led.lastSync != null)
                  Text(
                    'Última sync: ${_formatTime(led.lastSync!)}',
                    style: TextStyle(color: kTextSecondary, fontSize: 10),
                  ),
              ],
            ),
          ),
          // Estado letrero
          Column(
            children: [
              Text(led.ledStatusEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                led.ledStatusLabel,
                style: TextStyle(
                    color: _statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kTextSecondary, size: 14),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: kTextSecondary,
                fontSize: 10,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ConfigField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _ConfigField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: kTextColor, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: kTextSecondary, fontSize: 11),
        hintStyle:
            TextStyle(color: kTextSecondary.withValues(alpha: 0.4), fontSize: 12),
        prefixIcon: Icon(icon, color: kTextSecondary, size: 16),
        filled: true,
        fillColor: kSurfaceColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kDividerColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kDividerColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kGreenActive, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _ProtocolSelector extends StatelessWidget {
  final LedProtocol selected;
  final ValueChanged<LedProtocol> onChanged;

  const _ProtocolSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final protocols = [
      {
        'value': LedProtocol.http,
        'label': 'HTTP REST',
        'desc': 'ESP32 con servidor web\n(más fácil de configurar)',
        'icon': Icons.http,
      },
      {
        'value': LedProtocol.mqtt,
        'label': 'MQTT',
        'desc': 'Broker MQTT\n(más robusto para IoT)',
        'icon': Icons.hub_outlined,
      },
      {
        'value': LedProtocol.websocket,
        'label': 'WebSocket',
        'desc': 'Conexión directa\n(tiempo real)',
        'icon': Icons.bolt_outlined,
      },
    ];

    return Column(
      children: protocols.map((p) {
        final isSelected = selected == p['value'];
        return GestureDetector(
          onTap: () => onChanged(p['value'] as LedProtocol),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? kGreenActive.withValues(alpha: 0.1)
                  : kSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? kGreenActive : kDividerColor,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(p['icon'] as IconData,
                    color: isSelected ? kGreenActive : kTextSecondary,
                    size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['label'] as String,
                          style: TextStyle(
                              color: isSelected ? kGreenActive : kTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text(p['desc'] as String,
                          style: TextStyle(
                              color: kTextSecondary, fontSize: 10, height: 1.4)),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: kGreenActive, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ConnectionGuide extends StatelessWidget {
  final LedProtocol protocol;
  const _ConnectionGuide({required this.protocol});

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGreenActive.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGreenActive.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: kGreenActive, size: 14),
              const SizedBox(width: 8),
              Text('GUÍA DE CONFIGURACIÓN',
                  style: TextStyle(
                      color: kGreenActive,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kGreenActive.withValues(alpha: 0.2),
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: TextStyle(
                                color: kGreenActive,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.value,
                          style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 11,
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  List<String> _getSteps() {
    switch (protocol) {
      case LedProtocol.http:
        return [
          'Carga el firmware HTTP en tu ESP32 (código Arduino disponible en la documentación)',
          'Conecta el ESP32 a la misma red WiFi que tu teléfono',
          'Encuentra la IP del ESP32 en tu router (o en el monitor serial)',
          'Ingresa esa IP arriba y presiona "Probar conexión"',
          'El letrero recibirá comandos POST a: http://[IP]/led',
        ];
      case LedProtocol.mqtt:
        return [
          'Instala un broker MQTT (ej: Mosquitto en Raspberry Pi o usa HiveMQ Cloud)',
          'Configura el ESP32 para suscribirse al topic: setstop/status',
          'Ingresa la IP del broker MQTT y puerto (1883 por defecto)',
          'El letrero escuchará mensajes JSON: {"status":"OCCUPIED"}',
          'Presiona "Probar" para verificar la conexión con el broker',
        ];
      case LedProtocol.websocket:
        return [
          'Carga el firmware WebSocket en tu ESP32',
          'El ESP32 actúa como servidor WebSocket en el puerto 81',
          'Ingresa la IP del ESP32 y puerto 81',
          'La app enviará el estado en tiempo real via WebSocket',
          'Latencia ultra-baja para sincronización instantánea',
        ];
    }
  }
}
