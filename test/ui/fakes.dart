import 'package:mitimiti/data/app_exception.dart';
import 'package:mitimiti/data/auth_repository.dart';
import 'package:mitimiti/data/group_data_repository.dart';
import 'package:mitimiti/data/groups_repository.dart';
import 'package:mitimiti/domain/models/group.dart';
import 'package:mitimiti/domain/models/category.dart';
import 'package:mitimiti/domain/models/expense.dart';
import 'package:mitimiti/domain/models/member.dart';
import 'package:mitimiti/domain/models/settlement.dart';

/// Registra las llamadas como texto para poder comparar fácil.
class FakeGroupDataRepository implements GroupDataRepository {
  final calls = <String>[];
  GroupData data = sampleData();

  @override
  Future<GroupData> load(String groupId) async => data;

  @override
  void Function() watch(String groupId, void Function() onChange) => () {};

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

class FakeAuthRepository implements AuthRepository {
  final calls = <String>[];
  AppException? failWith;

  @override
  bool get isSignedIn => false;

  @override
  String? currentUserId;

  @override
  Stream<bool> get signedInChanges => const Stream.empty();

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn $email $password');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    calls.add('signUp $email $password $name');
    if (failWith != null) throw failWith!;
    return true;
  }

  @override
  Future<void> signOut() async {}
}

class FakeGroupsRepository implements GroupsRepository {
  FakeGroupsRepository(this.groups);

  final List<Group> groups;

  @override
  Future<List<Group>> myGroups() async => groups;

  final calls = <String>[];

  @override
  Future<Group> createGroup(String name) async {
    calls.add('create $name');
    final group = Group(id: 'new', name: name, inviteCode: 'NEW123');
    groups.add(group);
    return group;
  }

  @override
  Future<Group> joinGroup(String code) async {
    calls.add('join $code');
    throw const AppException('Código de invitación inválido');
  }
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

Expense expense(
  String id,
  String paidBy,
  int cents, {
  String desc = '',
  String category = 'super',
  DateTime? date,
}) => Expense(
  id: id,
  groupId: 'g',
  paidBy: paidBy,
  amountCents: cents,
  categoryId: category,
  description: desc,
  date: date ?? DateTime(2026, 9, 30),
  createdBy: paidBy,
);
