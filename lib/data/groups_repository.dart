import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/group.dart';
import 'app_exception.dart';

class GroupsRepository {
  GroupsRepository(this._db);

  final SupabaseClient _db;

  /// Grupos del usuario actual (RLS filtra los ajenos).
  Future<List<Group>> myGroups() => _guard(() async {
    final rows = await _db
        .from('groups')
        .select('id, name, invite_code')
        .order('created_at');
    return rows.map(_fromRow).toList();
  });

  Future<Group> createGroup(String name) => _guard(() async {
    final row = await _db.rpc<Map<String, dynamic>>(
      'create_group',
      params: {'group_name': name},
    );
    return _fromRow(row);
  });

  Future<Group> joinGroup(String code) => _guard(() async {
    final row = await _db.rpc<Map<String, dynamic>>(
      'join_group',
      params: {'code': code},
    );
    return _fromRow(row);
  });

  Future<Group> renameGroup(String groupId, String name) => _guard(() async {
    final row = await _db
        .from('groups')
        .update({'name': name})
        .eq('id', groupId)
        .select('id, name, invite_code')
        .single();
    return _fromRow(row);
  });

  /// Saca al usuario actual del grupo. La base lo impide si tiene gastos o
  /// pagos registrados en el grupo (las FKs apuntan a su membresía): salir
  /// dejaría mal el saldo de los demás.
  Future<void> leaveGroup(String groupId) => _guard(() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw const AppException('No hay sesión iniciada.');
    try {
      await _db
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const AppException(
          'No podés salir: tenés gastos o pagos registrados en este grupo.',
        );
      }
      rethrow;
    }
  });

  static Group _fromRow(Map<String, dynamic> row) => Group(
    id: row['id'] as String,
    name: row['name'] as String,
    inviteCode: row['invite_code'] as String,
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      // Las RPCs lanzan mensajes ya pensados para el usuario
      // ("Código de invitación inválido").
      throw AppException(e.message);
    }
  }
}
