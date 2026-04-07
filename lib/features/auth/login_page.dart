import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart';
import '../students/student_dashboard.dart';
import '../teachers/teacher_dashboard.dart';
import '../admin/admin_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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
      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else if (role == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentDashboard()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB8C4D4),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                color: Color(0xFF3B5BDB),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.elliptical(180, 160),
                  topLeft: Radius.circular(200),
                  topRight: Radius.elliptical(120, 100),
                  bottomLeft: Radius.elliptical(100, 120),
                ),
              ),
            ),
          ),
          Positioned(
            top: -20,
            right: -30,
            child: Container(
              width: 160,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFF4C6EF5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.elliptical(150, 130),
                  bottomRight: Radius.elliptical(80, 100),
                  topLeft: Radius.elliptical(100, 80),
                  topRight: Radius.circular(160),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: -20,
            child: Container(
              width: 180,
              height: 200,
              decoration: const BoxDecoration(
                color: Color(0xFF3B5BDB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.elliptical(160, 140),
                  topRight: Radius.elliptical(80, 100),
                  bottomLeft: Radius.elliptical(100, 80),
                  bottomRight: Radius.circular(180),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -50,
            child: Container(
              width: 140,
              height: 160,
              decoration: const BoxDecoration(
                color: Color(0xFF4C6EF5),
                borderRadius: BorderRadius.only(
                  topRight: Radius.elliptical(140, 120),
                  bottomRight: Radius.elliptical(80, 100),
                  topLeft: Radius.circular(140),
                  bottomLeft: Radius.elliptical(100, 80),
                ),
              ),
            ),
          ),

          Center(
            child: Consumer<AuthController>(
              builder: (context, controller, _) {
                return Container(
                  width: 360,
                  height: 280,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Нэвтрэх',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 22),

                      if (controller.status == AuthStatus.error &&
                          controller.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            controller.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      _buildTextField(
                        controller: _usernameController,
                        label: 'Нэвтрэх нэр',
                        obscure: false,
                        onClear: () =>
                            setState(() => _usernameController.clear()),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Нууц үг',
                        obscure: _obscurePassword,
                        onClear: () =>
                            setState(() => _passwordController.clear()),
                        isPassword: true,
                      ),
                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: controller.status == AuthStatus.loading
                              ? null
                              : () => _onLogin(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A2E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: controller.status == AuthStatus.loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Нэвтрэх',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onClear,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFAAAAAA),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : IconButton(
                icon: const Icon(
                  Icons.cancel,
                  color: Color(0xFFAAAAAA),
                  size: 20,
                ),
                onPressed: onClear,
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B5BDB), width: 1.5),
        ),
      ),
    );
  }
}
