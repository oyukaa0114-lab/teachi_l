import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://uwgnimqkcbwgnonkijvi.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV3Z25pbXFrY2J3Z25vbmtpanZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxMzQ2MDksImV4cCI6MjA4ODcxMDYwOX0.ruPOCXdPklsg4slGy3gop-hD0qZOeiMasAElsrRta6Q',
    );
  }
}
