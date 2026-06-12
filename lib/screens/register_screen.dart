import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _selectedRole = 'produccion';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<Map<String, String>> _roles = [
    {'value': 'admin', 'label': 'Administrador', 'icon': '👑'},
    {'value': 'director', 'label': 'Director', 'icon': '🎬'},
    {'value': 'camarografo', 'label': 'Camarógrafo', 'icon': '📷'},
    {'value': 'produccion', 'label': 'Producción', 'icon': '🎙️'},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn));
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _doRegister() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthService>();
    final ok = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: _selectedRole,
    );
    if (ok && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: kTextSecondary, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('CREAR CUENTA',
              style: TextStyle(
                  color: kTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // ── Error ──────────────────────────────────────────
                      if (auth.error != null)
                        _ErrorBanner(
                            message: auth.error!,
                            onClose: () => auth.clearError()),

                      // ── Nombre completo ────────────────────────────────
                      _SectionLabel('DATOS PERSONALES'),
                      const SizedBox(height: 10),
                      _InputField(
                        controller: _nameCtrl,
                        label: 'Nombre completo',
                        hint: 'Carlos Martínez',
                        icon: Icons.person_outline,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Ingresa tu nombre';
                          if (v.trim().length < 3) return 'Nombre muy corto';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Email ──────────────────────────────────────────
                      _InputField(
                        controller: _emailCtrl,
                        label: 'Email',
                        hint: 'carlos@produccion.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu email';
                          if (!v.contains('@') || !v.contains('.'))
                            return 'Email inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Rol ────────────────────────────────────────────
                      _SectionLabel('ROL EN EL SET'),
                      const SizedBox(height: 10),
                      _RoleSelector(
                        roles: _roles,
                        selectedRole: _selectedRole,
                        onChanged: (r) => setState(() => _selectedRole = r),
                      ),
                      const SizedBox(height: 24),

                      // ── Contraseña ─────────────────────────────────────
                      _SectionLabel('SEGURIDAD'),
                      const SizedBox(height: 10),
                      _InputField(
                        controller: _passwordCtrl,
                        label: 'Contraseña',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: kTextSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Ingresa una contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _InputField(
                        controller: _confirmCtrl,
                        label: 'Confirmar contraseña',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscure: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: kTextSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (v) {
                          if (v != _passwordCtrl.text)
                            return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // ── Botón registrar ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _doRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreenActive,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                kGreenActive.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('CREAR CUENTA',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.5)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            color: kTextSecondary,
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600));
  }
}

class _RoleSelector extends StatelessWidget {
  final List<Map<String, String>> roles;
  final String selectedRole;
  final ValueChanged<String> onChanged;

  const _RoleSelector({
    required this.roles,
    required this.selectedRole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.8,
      children: roles.map((role) {
        final isSelected = selectedRole == role['value'];
        return GestureDetector(
          onTap: () => onChanged(role['value']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? kGreenActive.withValues(alpha: 0.15)
                  : kSurfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? kGreenActive : kDividerColor,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(role['icon']!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  role['label']!,
                  style: TextStyle(
                    color: isSelected ? kGreenActive : kTextSecondary,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(color: kTextColor, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: kTextSecondary, fontSize: 12),
        hintStyle:
            TextStyle(color: kTextSecondary.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: kTextSecondary, size: 18),
        suffixIcon: suffixIcon,
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
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kRedActive)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kRedActive, width: 1.5)),
        errorStyle: TextStyle(color: kRedActive, fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kRedActive.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRedActive.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: kRedActive, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: kRedActive, fontSize: 12))),
          GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close, color: kRedActive, size: 16)),
        ],
      ),
    );
  }
}
