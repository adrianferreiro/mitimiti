import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Perfil del usuario actual (tabla `profiles`).
class ProfileRepository {
  ProfileRepository(this._db);

  final SupabaseClient _db;

  String get _userId {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const AppException('No hay sesión iniciada.');
    return id;
  }

  Future<String> myDisplayName() => _guard(() async {
    final row = await _db
        .from('profiles')
        .select('display_name')
        .eq('id', _userId)
        .single();
    return row['display_name'] as String;
  });

  Future<void> updateDisplayName(String name) => _guard(
    () => _db.from('profiles').update({'display_name': name}).eq('id', _userId),
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw AppException('No se pudo completar la operación: ${e.message}');
    }
  }
}
