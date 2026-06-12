import 'package:flutter/material.dart';

// ─── Colores principales ───────────────────────────────────────────────────
const Color kBackgroundColor = Color(0xFF0D0D0D);
const Color kSurfaceColor = Color(0xFF1A1A1A);
const Color kTextColor = Color(0xFFE8E8E8);
const Color kTextSecondary = Color(0xFF9E9E9E);
const Color kDividerColor = Color(0xFF2A2A2A);

// Botón ROJO - RECORD
const Color kRedActive = Color(0xFFE53935);
const Color kRedGlow = Color(0xFFFF5252);
const Color kRedDim = Color(0xFF5D1A1A);

// Botón AMARILLO - PREP
const Color kYellowActive = Color(0xFFFDD835);
const Color kYellowGlow = Color(0xFFFFFF00);
const Color kYellowDim = Color(0xFF5D4E10);

// Botón VERDE - LIBRE
const Color kGreenActive = Color(0xFF43A047);
const Color kGreenGlow = Color(0xFF66BB6A);
const Color kGreenDim = Color(0xFF1A3D1A);

// ─── Tipografía ────────────────────────────────────────────────────────────
const String kFontFamily = 'RobotoMono';

const TextStyle kTimerStyle = TextStyle(
  fontFamily: kFontFamily,
  fontSize: 38,
  fontWeight: FontWeight.bold,
  color: kTextColor,
  letterSpacing: 2,
);

const TextStyle kSceneStyle = TextStyle(
  fontSize: 14,
  color: kTextSecondary,
  letterSpacing: 1.2,
);

const TextStyle kButtonLabelStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
  color: Colors.white,
  letterSpacing: 1.5,
);

const TextStyle kStatusBarStyle = TextStyle(
  fontSize: 11,
  color: kTextSecondary,
  letterSpacing: 0.8,
);

// ─── Dimensiones ───────────────────────────────────────────────────────────
const double kButtonSize = 130.0;
const double kButtonSpacing = 18.0;
const double kGlowRadius = 30.0;
