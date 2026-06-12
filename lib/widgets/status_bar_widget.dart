import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_status_service.dart';
import '../utils/constants.dart';

class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceStatusService>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(top: BorderSide(color: kDividerColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatusItem(
            icon: _batteryIcon(device.batteryLevel, device.isCharging),
            iconColor: _batteryColor(device.batteryLevel),
            label: 'BATERÍA: ${device.batteryLevel}%',
          ),
          _StatusItem(
            icon: _signalIcon(device.signalLevel),
            iconColor: _signalColor(device.signalLevel),
            label: 'SEÑAL: ${device.signalLevel}%',
            rightAlign: true,
          ),
        ],
      ),
    );
  }

  IconData _batteryIcon(int level, bool charging) {
    if (charging) return Icons.battery_charging_full;
    if (level >= 90) return Icons.battery_full;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_3_bar;
    if (level >= 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  Color _batteryColor(int level) {
    if (level >= 50) return kGreenActive;
    if (level >= 20) return kYellowActive;
    return kRedActive;
  }

  IconData _signalIcon(int level) {
    if (level >= 80) return Icons.wifi;
    if (level >= 40) return Icons.wifi_2_bar;
    if (level > 0) return Icons.wifi_1_bar;
    return Icons.wifi_off;
  }

  Color _signalColor(int level) {
    if (level >= 80) return kGreenActive;
    if (level >= 40) return kYellowActive;
    if (level > 0) return kRedActive;
    return kTextSecondary;
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool rightAlign;

  const _StatusItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.rightAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, color: iconColor, size: 14),
      const SizedBox(width: 6),
      Text(label, style: kStatusBarStyle),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: rightAlign ? children.reversed.toList() : children,
    );
  }
}
