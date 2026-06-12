import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin', 'director', 'camarografo', 'produccion'
  final String avatarInitials;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarInitials,
    required this.createdAt,
  });

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'director':
        return 'Director';
      case 'camarografo':
        return 'Camarógrafo';
      case 'produccion':
        return 'Producción';
      default:
        return 'Usuario';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatarInitials': avatarInitials,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        role: json['role'],
        avatarInitials: json['avatarInitials'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get error => _error;

  AuthService() {
    _loadSession();
  }

  // ─── Hash password ────────────────────────────────────────────────────────
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Iniciar sesión ───────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800)); // simula red

    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('users_db') ?? '[]';
      final List<dynamic> users = jsonDecode(usersJson);

      final hashedPwd = _hashPassword(password);
      final userMap = users.firstWhere(
        (u) =>
            u['email'].toString().toLowerCase() == email.toLowerCase() &&
            u['passwordHash'] == hashedPwd,
        orElse: () => null,
      );

      if (userMap == null) {
        _error = 'Email o contraseña incorrectos';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = UserModel.fromJson(userMap);
      await _saveSession();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al iniciar sesión';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Registrar usuario ────────────────────────────────────────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('users_db') ?? '[]';
      final List<dynamic> users = jsonDecode(usersJson);

      // Verificar si el email ya existe
      final exists = users.any(
          (u) => u['email'].toString().toLowerCase() == email.toLowerCase());
      if (exists) {
        _error = 'Este email ya está registrado';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Crear usuario
      final initials = name
          .trim()
          .split(' ')
          .take(2)
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
          .join();

      final newUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        email: email.trim().toLowerCase(),
        role: role,
        avatarInitials: initials,
        createdAt: DateTime.now(),
      );

      final userWithPwd = {
        ...newUser.toJson(),
        'passwordHash': _hashPassword(password),
      };

      users.add(userWithPwd);
      await prefs.setString('users_db', jsonEncode(users));

      _currentUser = newUser;
      await _saveSession();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al registrar usuario';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Cerrar sesión ────────────────────────────────────────────────────────
  Future<void> logout() async {
    _currentUser = null;
    _error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_session');
    notifyListeners();
  }

  // ─── Persistencia de sesión ───────────────────────────────────────────────
  Future<void> _saveSession() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_session', jsonEncode(_currentUser!.toJson()));
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString('current_session');
      if (sessionJson != null) {
        _currentUser = UserModel.fromJson(jsonDecode(sessionJson));
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
