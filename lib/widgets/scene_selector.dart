import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/set_controller.dart';
import '../utils/constants.dart';

class SceneSelector extends StatelessWidget {
  const SceneSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SetController>();

    return GestureDetector(
      onTap: () => _showEditDialog(context, controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kDividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter_outlined, color: kTextSecondary, size: 14),
            const SizedBox(width: 8),
            Text(controller.sceneLabel, style: kSceneStyle),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, color: kTextSecondary, size: 12),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, SetController controller) {
    showDialog(
      context: context,
      builder: (ctx) => _SceneEditDialog(controller: controller),
    );
  }
}

class _SceneEditDialog extends StatefulWidget {
  final SetController controller;
  const _SceneEditDialog({required this.controller});

  @override
  State<_SceneEditDialog> createState() => _SceneEditDialogState();
}

class _SceneEditDialogState extends State<_SceneEditDialog> {
  late int _tema;
  late int _escena;

  @override
  void initState() {
    super.initState();
    _tema = widget.controller.tema;
    _escena = widget.controller.escena;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EDITAR ESCENA',
              style: TextStyle(
                color: kTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            _CounterRow(
              label: 'TEMA',
              value: _tema,
              onIncrement: () => setState(() => _tema = (_tema % 99) + 1),
              onDecrement: () =>
                  setState(() => _tema = _tema > 1 ? _tema - 1 : 99),
            ),
            const SizedBox(height: 16),
            _CounterRow(
              label: 'ESCENA',
              value: _escena,
              onIncrement: () => setState(() => _escena = (_escena % 99) + 1),
              onDecrement: () =>
                  setState(() => _escena = _escena > 1 ? _escena - 1 : 99),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: kTextSecondary,
                    ),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Actualizar valores
                      while (widget.controller.tema != _tema) {
                        if (widget.controller.tema < _tema) {
                          widget.controller.incrementTema();
                        } else {
                          widget.controller.decrementTema();
                        }
                      }
                      while (widget.controller.escena != _escena) {
                        if (widget.controller.escena < _escena) {
                          widget.controller.incrementEscena();
                        } else {
                          widget.controller.decrementEscena();
                        }
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreenActive,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('GUARDAR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: kTextSecondary, fontSize: 12, letterSpacing: 1.5)),
        Row(
          children: [
            IconButton(
              onPressed: onDecrement,
              icon: Icon(Icons.remove_circle_outline, color: kTextSecondary),
            ),
            SizedBox(
              width: 40,
              child: Text(
                value.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: onIncrement,
              icon: Icon(Icons.add_circle_outline, color: kTextColor),
            ),
          ],
        ),
      ],
    );
  }
}
