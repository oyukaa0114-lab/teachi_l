import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart';
import '../students/student_dashboard.dart';
import '../teachers/teacher_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../super_admin/super_admin_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onLogin(BuildContext context) async {
    final controller = context.read<AuthController>();
    final success = await controller.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (success && context.mounted) {
      final role = controller.currentUser?['role'] as String?;
      Widget destination;
      switch (role) {
        case 'admin':
          destination = const AdminDashboard();
          break;
        case 'super_admin':
          destination = const SuperAdminDashboard();
          break;
        case 'teacher':
          destination = const TeacherDashboard();
          break;
        default:
          destination = const StudentDashboard();
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1437), Color(0xFF1B2B65), Color(0xFF0F1C3F)],
          ),
        ),
        child: Stack(
          children: [
            // ── Арын чимэглэл ──
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B5BDB).withOpacity(0.3),
                      const Color(0xFF3B5BDB).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4C6EF5).withOpacity(0.2),
                      const Color(0xFF4C6EF5).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.3,
              left: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.15),
                      const Color(0xFF6C63FF).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // ── Контент ──
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: SizedBox(
                  height:
                      size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // ── Лого + гарчиг ──
                      FadeTransition(
                        opacity: _fadeIn,
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF4C6EF5),
                                    Color(0xFF4C6EF5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1A1A2E,
                                    ).withOpacity(0.4),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Image.asset(
                                  'assets/images/logo.bg.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Тавтай морил',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Системд нэвтрэхийн тулд мэдээллээ оруулна уу',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 1),

                      // ── Login форм ──
                      SlideTransition(
                        position: _slideUp,
                        child: FadeTransition(
                          opacity: _fadeIn,
                          child: Consumer<AuthController>(
                            builder: (context, controller, _) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Алдааны мессеж
                                    if (controller.status == AuthStatus.error &&
                                        controller.errorMessage != null)
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFFF4757,
                                          ).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFFFF4757,
                                            ).withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              color: Color(0xFFFF6B7A),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                controller.errorMessage!,
                                                style: const TextStyle(
                                                  color: Color(0xFFFF6B7A),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Нэвтрэх нэр
                                    _buildInput(
                                      controller: _usernameController,
                                      label: 'Нэвтрэх нэр',
                                      icon: Icons.person_outline_rounded,
                                      obscure: false,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) {
                                        if (controller.status !=
                                            AuthStatus.loading) {
                                          _onLogin(context);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Нууц үг
                                    _buildInput(
                                      controller: _passwordController,
                                      label: 'Нууц үг',
                                      icon: Icons.lock_outline_rounded,
                                      obscure: _obscurePassword,
                                      isPassword: true,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) {
                                        if (controller.status !=
                                            AuthStatus.loading) {
                                          _onLogin(context);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    // Нэвтрэх товч
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed:
                                            controller.status ==
                                                AuthStatus.loading
                                            ? null
                                            : () => _onLogin(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF4C6EF5,
                                          ),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: const Color(
                                            0xFF4C6EF5,
                                          ).withOpacity(0.5),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child:
                                            controller.status ==
                                                AuthStatus.loading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text(
                                                'Нэвтрэх',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ── Доод хэсэг ──
                      FadeTransition(
                        opacity: _fadeIn,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            '© 2026 Teachi',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    bool isPassword = false,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF4C6EF5),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.35), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withOpacity(0.3),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4C6EF5), width: 1.5),
        ),
      ),
    );
  }
}
