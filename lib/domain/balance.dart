import 'models/expense.dart';
import 'models/settlement.dart';

/// Una transferencia sugerida para saldar el grupo.
class Debt {
  const Debt({
    required this.fromUserId,
    required this.toUserId,
    required this.amountCents,
  });

  final String fromUserId;
  final String toUserId;
  final int amountCents;

  @override
  bool operator ==(Object other) =>
      other is Debt &&
      other.fromUserId == fromUserId &&
      other.toUserId == toUserId &&
      other.amountCents == amountCents;

  @override
  int get hashCode => Object.hash(fromUserId, toUserId, amountCents);

  @override
  String toString() => 'Debt($fromUserId -> $toUserId: $amountCents)';
}

/// Saldo neto de cada miembro, en centavos.
///
/// Positivo: el grupo le debe. Negativo: le debe al grupo.
/// `neto = pagado − su parte + pagos enviados − pagos recibidos`.
///
/// Cada gasto se reparte en partes iguales entre [memberIds]. Si el monto no
/// es divisible, el que pagó absorbe los centavos sobrantes (los demás pagan
/// `amount ~/ n`), así la suma de las partes es siempre exacta.
///
/// Lanza [ArgumentError] si un gasto o pago referencia a alguien que no está
/// en [memberIds].
Map<String, int> netBalances({
  required List<String> memberIds,
  required List<Expense> expenses,
  List<Settlement> settlements = const [],
}) {
  if (memberIds.isEmpty) {
    throw ArgumentError.value(memberIds, 'memberIds', 'no puede estar vacío');
  }
  final balances = {for (final id in memberIds) id: 0};
  final n = memberIds.length;

  void checkMember(String userId) {
    if (!balances.containsKey(userId)) {
      throw ArgumentError('Usuario $userId no es miembro del grupo');
    }
  }

  for (final e in expenses) {
    checkMember(e.paidBy);
    final share = e.amountCents ~/ n;
    for (final id in memberIds) {
      if (id != e.paidBy) {
        balances[id] = balances[id]! - share;
        balances[e.paidBy] = balances[e.paidBy]! + share;
      }
    }
  }

  for (final s in settlements) {
    checkMember(s.fromUserId);
    checkMember(s.toUserId);
    balances[s.fromUserId] = balances[s.fromUserId]! + s.amountCents;
    balances[s.toUserId] = balances[s.toUserId]! - s.amountCents;
  }

  return balances;
}

/// Convierte saldos netos en la menor cantidad razonable de transferencias:
/// empareja al mayor deudor con el mayor acreedor hasta que todo queda en 0.
/// Empates se ordenan por id para que el resultado sea determinístico.
List<Debt> simplifyDebts(Map<String, int> balances) {
  int byAmountThenId(MapEntry<String, int> a, MapEntry<String, int> b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  final creditors = [
    for (final e in balances.entries)
      if (e.value > 0) MapEntry(e.key, e.value),
  ]..sort(byAmountThenId);
  final debtors = [
    for (final e in balances.entries)
      if (e.value < 0) MapEntry(e.key, -e.value),
  ]..sort(byAmountThenId);

  final debts = <Debt>[];
  var i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final amount = debtors[i].value < creditors[j].value
        ? debtors[i].value
        : creditors[j].value;
    debts.add(
      Debt(
        fromUserId: debtors[i].key,
        toUserId: creditors[j].key,
        amountCents: amount,
      ),
    );
    debtors[i] = MapEntry(debtors[i].key, debtors[i].value - amount);
    creditors[j] = MapEntry(creditors[j].key, creditors[j].value - amount);
    if (debtors[i].value == 0) i++;
    if (creditors[j].value == 0) j++;
  }
  return debts;
}
