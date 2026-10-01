import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Supabase Project URL & Anon/Publishable Key
  static const String supabaseUrl = 'https://wvmjshmpboquzyqwacxw.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_uBli1Mro0fw58WBCEeYv3A_gWv7zwop';

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => client.auth.currentUser?.id;
  static String? get currentUserEmail => client.auth.currentUser?.email;

  static Future<void> initialize({String? customUrl, String? customAnonKey}) async {
    // ignore: deprecated_member_use
    await Supabase.initialize(
      url: customUrl ?? supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: customAnonKey ?? supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}
