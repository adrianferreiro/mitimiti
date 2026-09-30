import 'models/expense.dart';

/// Primer día del mes de [date], sin hora. Identifica un mes.
DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

/// Gastos de [month] (ver [monthOf]), o todos si [month] es `null`.
List<Expense> expensesInMonth(List<Expense> expenses, DateTime? month) {
  if (month == null) return expenses;
  return [
    for (final e in expenses)
      if (e.date.year == month.year && e.date.month == month.month) e,
  ];
}

/// Total gastado por categoría, en centavos, de mayor a menor (empates por
/// id para que el orden sea estable).
List<MapEntry<String, int>> totalsByCategory(List<Expense> expenses) {
  final totals = <String, int>{};
  for (final e in expenses) {
    totals[e.categoryId] = (totals[e.categoryId] ?? 0) + e.amountCents;
  }
  return totals.entries.toList()..sort((a, b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
}
