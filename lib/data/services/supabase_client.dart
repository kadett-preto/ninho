import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Wrapper fino sobre Supabase.instance. Centraliza bootstrap e dá um ponto
// único de injeção/mock para os Services do data layer (IDEA.md §6.2).
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  // Chamar uma única vez no bootstrap do app, antes de runApp.
  static Future<void> init() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty) {
      throw StateError('SUPABASE_URL ausente no .env');
    }
    if (anonKey == null || anonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY ausente no .env');
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
