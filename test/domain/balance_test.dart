import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/domain/balance.dart';
import 'package:mitimiti/domain/models/expense.dart';
import 'package:mitimiti/domain/models/settlement.dart';

var _seq = 0;

Expense _expense(String paidBy, int amountCents) => Expense(
  id: 'e${_seq++}',
  groupId: 'g',
  paidBy: paidBy,
  amountCents: amountCents,
  categoryId: 'c',
  date: DateTime(2026, 9, 30),
  createdBy: paidBy,
);

Settlement _settlement(String from, String to, int amountCents) => Settlement(
  id: 's${_seq++}',
  groupId: 'g',
  fromUserId: from,
  toUserId: to,
  amountCents: amountCents,
  date: DateTime(2026, 9, 30),
);

int _sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

void main() {
  group('netBalances', () {
    test('sin gastos todos quedan en 0', () {
      expect(netBalances(memberIds: ['a', 'b'], expenses: []), {
        'a': 0,
        'b': 0,
      });
    });

    test('pareja: uno paga, el otro debe la mitad', () {
      final b = netBalances(
        memberIds: ['a', 'b'],
        expenses: [_expense('a', 10000)],
      );
      expect(b, {'a': 5000, 'b': -5000});
    });

    test('pareja: gastos de ambos se compensan', () {
      final b = netBalances(
        memberIds: ['a', 'b'],
        expenses: [
          _expense('a', 30000),
          _expense('b', 10000),
          _expense('a', 5000),
        ],
      );
      // a pagó 35000, b 10000; total 45000 → 22500 c/u.
      expect(b, {'a': 12500, 'b': -12500});
    });

    test('monto impar: el que pagó absorbe el centavo', () {
      final b = netBalances(
        memberIds: ['a', 'b'],
        expenses: [_expense('a', 101)],
      );
      expect(b, {'a': 50, 'b': -50});
    });

    test('tres miembros con resto: la suma siempre da 0', () {
      final b = netBalances(
        memberIds: ['a', 'b', 'c'],
        expenses: [_expense('a', 100), _expense('b', 1001)],
      );
      expect(b, {'a': 66 - 333, 'b': 666 - 33, 'c': -33 - 333});
      expect(_sum(b), 0);
    });

    test('saldar la deuda deja todo en 0', () {
      final b = netBalances(
        memberIds: ['a', 'b'],
        expenses: [_expense('a', 10000)],
        settlements: [_settlement('b', 'a', 5000)],
      );
      expect(b, {'a': 0, 'b': 0});
    });

    test('pago parcial reduce la deuda', () {
      final b = netBalances(
        memberIds: ['a', 'b'],
        expenses: [_expense('a', 10000)],
        settlements: [_settlement('b', 'a', 2000)],
      );
      expect(b, {'a': 3000, 'b': -3000});
    });

    test('pagador fuera del grupo lanza error', () {
      expect(
        () =>
            netBalances(memberIds: ['a', 'b'], expenses: [_expense('x', 100)]),
        throwsArgumentError,
      );
    });

    test('grupo vacío lanza error', () {
      expect(
        () => netBalances(memberIds: [], expenses: []),
        throwsArgumentError,
      );
    });
  });

  group('simplifyDebts', () {
    test('todo saldado: sin transferencias', () {
      expect(simplifyDebts({'a': 0, 'b': 0}), isEmpty);
    });

    test('pareja: una transferencia', () {
      expect(simplifyDebts({'a': 5000, 'b': -5000}), [
        const Debt(fromUserId: 'b', toUserId: 'a', amountCents: 5000),
      ]);
    });

    test('grupo: minimiza transferencias y cubre todos los saldos', () {
      final balances = {'a': 6000, 'b': -1000, 'c': -2000, 'd': -3000};
      final debts = simplifyDebts(balances);
      expect(debts, [
        const Debt(fromUserId: 'd', toUserId: 'a', amountCents: 3000),
        const Debt(fromUserId: 'c', toUserId: 'a', amountCents: 2000),
        const Debt(fromUserId: 'b', toUserId: 'a', amountCents: 1000),
      ]);

      final after = Map.of(balances);
      for (final d in debts) {
        after[d.fromUserId] = after[d.fromUserId]! + d.amountCents;
        after[d.toUserId] = after[d.toUserId]! - d.amountCents;
      }
      expect(after.values, everyElement(0));
    });
  });

  group('validaciones de modelos', () {
    test('gasto con monto no positivo', () {
      expect(() => _expense('a', 0), throwsArgumentError);
    });

    test('pago a uno mismo', () {
      expect(() => _settlement('a', 'a', 100), throwsArgumentError);
    });
  });
}
