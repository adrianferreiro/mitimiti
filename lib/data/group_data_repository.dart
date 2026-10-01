import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/category.dart';
import '../domain/models/expense.dart';
import '../domain/models/member.dart';
import '../domain/models/settlement.dart';
import 'app_exception.dart';

/// Todo lo que se muestra dentro de un grupo, cargado de una vez.
class GroupData {
  const GroupData({
    required this.members,
    required this.categories,
    required this.expenses,
    required this.settlements,
  });

  final List<Member> members;
  final List<Category> categories;

  /// Más recientes primero.
  final List<Expense> expenses;

  /// Más recientes primero.
  final List<Settlement> settlements;

  List<String> get memberIds => [for (final m in members) m.userId];

  String memberName(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m.displayName;
    }
    return 'Ex miembro';
  }

  String categoryName(String categoryId) {
    for (final c in categories) {
      if (c.id == categoryId) return c.name;
    }
    return 'Sin categoría';
  }
}

/// Miembros, categorías, gastos y pagos de un grupo.
class GroupDataRepository {
  GroupDataRepository(this._db);

  final SupabaseClient _db;

  Future<GroupData> load(String groupId) => _guard(() async {
    final results = await Future.wait([
      _db
          .from('group_members')
          .select('user_id, profiles(display_name)')
          .eq('group_id', groupId)
          .order('joined_at'),
      _db
          .from('categories')
          .select('id, group_id, name')
          .eq('group_id', groupId)
          .order('name'),
      _db
          .from('expenses')
          .select(
            'id, group_id, paid_by, amount_cents, category_id, description, '
            'spent_on, created_by',
          )
          .eq('group_id', groupId)
          .order('spent_on', ascending: false)
          .order('created_at', ascending: false),
      _db
          .from('settlements')
          .select(
            'id, group_id, from_user_id, to_user_id, amount_cents, settled_on',
          )
          .eq('group_id', groupId)
          .order('settled_on', ascending: false)
          .order('created_at', ascending: false),
    ]);
    return GroupData(
      members: results[0].map(_memberFromRow).toList(),
      categories: results[1].map(_categoryFromRow).toList(),
      expenses: results[2].map(_expenseFromRow).toList(),
      settlements: results[3].map(_settlementFromRow).toList(),
    );
  });

  /// Llama a [onChange] cuando alguien cambia gastos, pagos o miembros del
  /// grupo. Devuelve la función para dejar de escuchar.
  ///
  /// Los DELETE de Realtime no traen `group_id` (solo la clave primaria), así
  /// que no se pueden filtrar por grupo: se escuchan todos y se recarga igual.
  void Function() watch(String groupId, void Function() onChange) {
    final byGroup = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'group_id',
      value: groupId,
    );
    var channel = _db.channel('group:$groupId');
    for (final table in const ['expenses', 'settlements', 'group_members']) {
      for (final event in const [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update,
      ]) {
        channel = channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          filter: byGroup,
          callback: (_) => onChange(),
        );
      }
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      );
    }
    channel.subscribe();
    return () => _db.removeChannel(channel);
  }

  Future<void> addExpense({
    required String groupId,
    required String paidBy,
    required int amountCents,
    required String categoryId,
    required String description,
    required DateTime date,
  }) => _guard(
    () => _db.from('expenses').insert({
      'group_id': groupId,
      'paid_by': paidBy,
      'amount_cents': amountCents,
      'category_id': categoryId,
      'description': description,
      'spent_on': _date(date),
    }),
  );

  Future<void> updateExpense({
    required String expenseId,
    required String paidBy,
    required int amountCents,
    required String categoryId,
    required String description,
    required DateTime date,
  }) => _guard(
    () => _db
        .from('expenses')
        .update({
          'paid_by': paidBy,
          'amount_cents': amountCents,
          'category_id': categoryId,
          'description': description,
          'spent_on': _date(date),
        })
        .eq('id', expenseId),
  );

  Future<void> deleteExpense(String expenseId) =>
      _guard(() => _db.from('expenses').delete().eq('id', expenseId));

  Future<void> addSettlement({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required int amountCents,
    required DateTime date,
  }) => _guard(
    () => _db.from('settlements').insert({
      'group_id': groupId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount_cents': amountCents,
      'settled_on': _date(date),
    }),
  );

  Future<void> deleteSettlement(String settlementId) =>
      _guard(() => _db.from('settlements').delete().eq('id', settlementId));

  /// `date` de Postgres: "YYYY-MM-DD", sin hora ni zona.
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Member _memberFromRow(Map<String, dynamic> row) => Member(
    userId: row['user_id'] as String,
    displayName:
        (row['profiles'] as Map<String, dynamic>?)?['display_name']
            as String? ??
        'Sin nombre',
  );

  static Category _categoryFromRow(Map<String, dynamic> row) => Category(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    name: row['name'] as String,
  );

  static Expense _expenseFromRow(Map<String, dynamic> row) => Expense(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    paidBy: row['paid_by'] as String,
    amountCents: row['amount_cents'] as int,
    categoryId: row['category_id'] as String,
    description: row['description'] as String,
    date: DateTime.parse(row['spent_on'] as String),
    createdBy: row['created_by'] as String,
  );

  static Settlement _settlementFromRow(Map<String, dynamic> row) => Settlement(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    fromUserId: row['from_user_id'] as String,
    toUserId: row['to_user_id'] as String,
    amountCents: row['amount_cents'] as int,
    date: DateTime.parse(row['settled_on'] as String),
  );

  Future<void> addCategory(String groupId, String name) => _guard(
    () => _db.from('categories').insert({'group_id': groupId, 'name': name}),
    onDuplicate: 'Ya existe una categoría con ese nombre.',
  );

  Future<void> renameCategory(String categoryId, String name) => _guard(
    () => _db.from('categories').update({'name': name}).eq('id', categoryId),
    onDuplicate: 'Ya existe una categoría con ese nombre.',
  );

  /// La base no deja borrar una categoría que tenga gastos (FK).
  Future<void> deleteCategory(String categoryId) => _guard(
    () => _db.from('categories').delete().eq('id', categoryId),
    onForeignKey:
        'No se puede borrar: hay gastos con esta categoría. '
        'Cambiales la categoría primero.',
  );

  /// Traduce errores de Postgres a mensajes para el usuario. [onDuplicate]
  /// es para violaciones de unicidad (23505) y [onForeignKey] para FKs
  /// (23503).
  Future<T> _guard<T>(
    Future<T> Function() action, {
    String? onDuplicate,
    String? onForeignKey,
  }) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      if (e.code == '23505' && onDuplicate != null) {
        throw AppException(onDuplicate);
      }
      if (e.code == '23503' && onForeignKey != null) {
        throw AppException(onForeignKey);
      }
      throw AppException('No se pudo completar la operación: ${e.message}');
    }
  }
}
