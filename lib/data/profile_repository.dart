import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/notification_prefs.dart';
import 'app_exception.dart';

/// Perfil del usuario actual (tabla `profiles`) y sus preferencias de
/// notificaciones (`notification_prefs`).
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

  /// Sin fila guardada = todas activadas.
  Future<NotificationPrefs> myNotificationPrefs() => _guard(() async {
    final row = await _db
        .from('notification_prefs')
        .select('expense_new, expense_changed, settlement, member_joined')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return const NotificationPrefs();
    return NotificationPrefs(
      expenseNew: row['expense_new'] as bool,
      expenseChanged: row['expense_changed'] as bool,
      settlement: row['settlement'] as bool,
      memberJoined: row['member_joined'] as bool,
    );
  });

  Future<void> updateNotificationPrefs(NotificationPrefs prefs) => _guard(
    () => _db.from('notification_prefs').upsert({
      'user_id': _userId,
      'expense_new': prefs.expenseNew,
      'expense_changed': prefs.expenseChanged,
      'settlement': prefs.settlement,
      'member_joined': prefs.memberJoined,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw AppException('No se pudo completar la operación: ${e.message}');
    }
  }
}
