import 'package:mitimiti/data/group_data_repository.dart';
import 'package:mitimiti/domain/models/category.dart';
import 'package:mitimiti/domain/models/expense.dart';
import 'package:mitimiti/domain/models/member.dart';
import 'package:mitimiti/domain/models/settlement.dart';

/// Registra las llamadas como texto para poder comparar fácil.
class FakeGroupDataRepository implements GroupDataRepository {
  final calls = <String>[];

  @override
  Future<GroupData> load(String groupId) async => throw UnimplementedError();

  @override
  Future<void> addExpense({
    required String groupId,
    required String paidBy,
    required int amountCents,
    required String categoryId,
    required String description,
    required DateTime date,
  }) async => calls.add(
    'add $groupId $paidBy $amountCents $categoryId "$description" '
    '${date.year}-${date.month}-${date.day}',
  );

  @override
  Future<void> updateExpense({
    required String expenseId,
    required String paidBy,
    required int amountCents,
    required String categoryId,
    required String description,
    required DateTime date,
  }) async => calls.add(
    'update $expenseId $paidBy $amountCents $categoryId "$description"',
  );

  @override
  Future<void> deleteExpense(String expenseId) async =>
      calls.add('delete $expenseId');

  @override
  Future<void> addSettlement({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required int amountCents,
    required DateTime date,
  }) async => calls.add('settle $fromUserId $toUserId $amountCents');

  @override
  Future<void> deleteSettlement(String settlementId) async =>
      calls.add('deleteSettlement $settlementId');
}

GroupData sampleData({
  List<Expense> expenses = const [],
  List<Settlement> settlements = const [],
}) => GroupData(
  members: const [
    Member(userId: 'ana', displayName: 'Ana'),
    Member(userId: 'juan', displayName: 'Juan'),
  ],
  categories: const [
    Category(id: 'super', groupId: 'g', name: 'Supermercado'),
    Category(id: 'serv', groupId: 'g', name: 'Servicios'),
  ],
  expenses: expenses,
  settlements: settlements,
);

Expense expense(String id, String paidBy, int cents, {String desc = ''}) =>
    Expense(
      id: id,
      groupId: 'g',
      paidBy: paidBy,
      amountCents: cents,
      categoryId: 'super',
      description: desc,
      date: DateTime(2026, 9, 30),
      createdBy: paidBy,
    );
