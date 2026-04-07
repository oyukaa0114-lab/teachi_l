import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        home: const LoginPage(),
      ),
    );
  }
}
