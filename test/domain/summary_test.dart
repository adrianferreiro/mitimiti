import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/domain/models/expense.dart';
import 'package:mitimiti/domain/summary.dart';

var _seq = 0;

Expense _expense(String category, int cents, DateTime date) => Expense(
  id: 'e${_seq++}',
  groupId: 'g',
  paidBy: 'a',
  amountCents: cents,
  categoryId: category,
  date: date,
  createdBy: 'a',
);

void main() {
  test('monthOf descarta día y hora', () {
    expect(monthOf(DateTime(2026, 9, 30, 23, 59)), DateTime(2026, 9));
  });

  group('expensesInMonth', () {
    final sep = _expense('c', 100, DateTime(2026, 9, 1));
    final sepEnd = _expense('c', 100, DateTime(2026, 9, 30));
    final oct = _expense('c', 100, DateTime(2026, 10, 1));
    final sepLastYear = _expense('c', 100, DateTime(2025, 9, 15));
    final all = [sep, sepEnd, oct, sepLastYear];

    test('filtra por mes y año', () {
      expect(expensesInMonth(all, DateTime(2026, 9)), [sep, sepEnd]);
      expect(expensesInMonth(all, DateTime(2026, 10)), [oct]);
      expect(expensesInMonth(all, DateTime(2026, 11)), isEmpty);
    });

    test('null devuelve todos', () {
      expect(expensesInMonth(all, null), all);
    });
  });

  test('totalsByCategory suma y ordena de mayor a menor', () {
    final d = DateTime(2026, 9, 1);
    final totals = totalsByCategory([
      _expense('super', 1000, d),
      _expense('luz', 5000, d),
      _expense('super', 3000, d),
      _expense('agua', 4000, d),
      _expense('gas', 4000, d),
    ]);
    expect(totals.map((e) => '${e.key}=${e.value}'), [
      'luz=5000',
      'agua=4000',
      'gas=4000',
      'super=4000',
    ]);
  });

  test('totalsByCategory sin gastos es vacío', () {
    expect(totalsByCategory([]), isEmpty);
  });
}
