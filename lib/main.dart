import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/students/student_dashboard.dart';
import 'features/teachers/teacher_dashboard.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/super_admin/super_admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: 'https://uwgnimqkcbwgnonkijvi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV3Z25pbXFrY2J3Z25vbmtpanZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxMzQ2MDksImV4cCI6MjA4ODcxMDYwOX0.ruPOCXdPklsg4slGy3gop-hD0qZOeiMasAElsrRta6Q',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthController())],
      child: MaterialApp(
        title: 'Teachi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BDB)),
          useMaterial3: true,
          textTheme: GoogleFonts.notoSansTextTheme(),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    // Session ачаалж байх үед spinner харуулна
    if (!auth.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1C3F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
        ),
      );
    }

    final user = auth.currentUser;
    if (user == null) return const LoginPage();

    switch (user['role'] as String?) {
      case 'admin':
        return const AdminDashboard();
      case 'teacher':
        return const TeacherDashboard();
      case 'super_admin':
        return const SuperAdminDashboard();
      default:
        return const StudentDashboard();
    }
  }
}
