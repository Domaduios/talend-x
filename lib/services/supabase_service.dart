import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cdukpuhcaxblngodzgav.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNkdWtwdWhjYXhibG5nb2R6Z2F2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU3MzYwMzMsImV4cCI6MjExMTMxMjAzM30.EKWdIiUcYjCVYqApuJ961PMK4tgrYev9KiPhiVJfKmA',
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static User? get currentUser => auth.currentUser;
  static String? get currentUserId => currentUser?.id;

  static Future<bool> signInWithGoogle() async {
    return await auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : 'com.iu.talendx://login-callback',
    );
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return await client.from('users').select().eq('id', uid).maybeSingle();
  }
}
