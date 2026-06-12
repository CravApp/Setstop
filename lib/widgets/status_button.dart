import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../utils/constants.dart';

class StatusButton extends StatefulWidget {
  final SetStatus status;
  final SetStatus currentStatus;
  final VoidCallback onTap;

  const StatusButton({
    super.key,
    required this.status,
    required this.currentStatus,
    required this.onTap,
  });

  @override
  State<StatusButton> createState() => _StatusButtonState();
}

class _StatusButtonState extends State<StatusButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isActive => widget.status == widget.currentStatus;

  Color get _activeColor {
    switch (widget.status) {
      case SetStatus.record:
        return kRedActive;
      case SetStatus.prep:
        return kYellowActive;
      case SetStatus.libre:
        return kGreenActive;
    }
  }

  Color get _dimColor {
    switch (widget.status) {
      case SetStatus.record:
        return kRedDim;
      case SetStatus.prep:
        return kYellowDim;
      case SetStatus.libre:
        return kGreenDim;
    }
  }

  Color get _glowColor {
    switch (widget.status) {
      case SetStatus.record:
        return kRedGlow;
      case SetStatus.prep:
        return kYellowGlow;
      case SetStatus.libre:
        return kGreenGlow;
    }
  }

  String get _topLabel {
    switch (widget.status) {
      case SetStatus.record:
        return 'RED';
      case SetStatus.prep:
        return 'YELLOW';
      case SetStatus.libre:
        return 'GREEN';
    }
  }

  String get _bottomLabel {
    switch (widget.status) {
      case SetStatus.record:
        return 'RECORD';
      case SetStatus.prep:
        return 'PREP';
      case SetStatus.libre:
        return 'LIBRE';
    }
  }

  void _onTapDown(TapDownDetails _) {
    _animController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _animController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: kButtonSize,
          height: kButtonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isActive ? _activeColor : _dimColor,
            border: Border.all(
              color: _isActive
                  ? _glowColor.withValues(alpha: 0.7)
                  : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: _isActive
                ? [
                    BoxShadow(
                      color: _glowColor.withValues(alpha: 0.55),
                      blurRadius: kGlowRadius,
                      spreadRadius: 6,
                    ),
                    BoxShadow(
                      color: _glowColor.withValues(alpha: 0.25),
                      blurRadius: 55,
                      spreadRadius: 12,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _topLabel,
                style: kButtonLabelStyle.copyWith(
                  fontSize: 13,
                  color: _isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _bottomLabel,
                style: kButtonLabelStyle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
