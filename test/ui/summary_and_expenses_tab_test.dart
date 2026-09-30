import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/data/group_data_repository.dart';
import 'package:mitimiti/ui/groups/expenses_tab.dart';
import 'package:mitimiti/ui/groups/summary_tab.dart';

import 'fakes.dart';

final _data = sampleData(
  expenses: [
    expense('e1', 'ana', 600000, category: 'super', date: DateTime(2026, 9, 5)),
    expense(
      'e2',
      'juan',
      200000,
      category: 'serv',
      date: DateTime(2026, 9, 20),
    ),
    expense('e3', 'juan', 100000, desc: 'Agosto', date: DateTime(2026, 8, 10)),
  ],
);

/// Envuelve una pestaña con el mes como estado, como hace GroupScreen.
class _Host extends StatefulWidget {
  const _Host(this.build);

  final Widget Function(DateTime?, void Function(DateTime?)) build;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  DateTime? month = DateTime(2026, 9);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: widget.build(month, (m) => setState(() => month = m))),
  );
}

Future<void> _pumpExpenses(WidgetTester tester, GroupData data) =>
    tester.pumpWidget(
      _Host(
        (month, onChanged) => ExpensesTab(
          data: data,
          month: month,
          onMonthChanged: onChanged,
          onRefresh: () async {},
          onTapExpense: (_) {},
        ),
      ),
    );

void main() {
  group('ExpensesTab', () {
    testWidgets('muestra solo los gastos del mes y navega', (tester) async {
      await _pumpExpenses(tester, _data);
      expect(find.text('Septiembre 2026'), findsOneWidget);
      expect(find.text(r'$8.000'), findsOneWidget); // total de septiembre
      expect(find.text('Agosto'), findsNothing);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pump();
      expect(find.text('Agosto 2026'), findsOneWidget);
      expect(find.text('Agosto'), findsOneWidget);
      expect(find.text(r'$1.000'), findsWidgets);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pump();
      expect(find.text('No hay gastos en julio 2026.'), findsOneWidget);
    });

    testWidgets('"Ver todo" muestra todos los meses', (tester) async {
      await _pumpExpenses(tester, _data);
      await tester.tap(find.text('Ver todo'));
      await tester.pump();

      expect(find.text('Todos los meses'), findsOneWidget);
      expect(find.text(r'$9.000'), findsOneWidget);
      expect(find.text('Agosto'), findsOneWidget);
    });
  });

  testWidgets('SummaryTab: totales por categoría y por persona del mes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        (month, onChanged) => SummaryTab(
          data: _data,
          month: month,
          onMonthChanged: onChanged,
          currentUserId: 'juan',
          onRefresh: () async {},
        ),
      ),
    );

    expect(find.text(r'$8.000'), findsOneWidget);
    expect(find.text(r'$4.000 por persona'), findsOneWidget);
    expect(find.text('Supermercado'), findsOneWidget);
    expect(find.text(r'$6.000  ·  75%'), findsNWidgets(2)); // categoría y Ana
    expect(find.text(r'$2.000  ·  25%'), findsNWidgets(2)); // Servicios y Juan
    expect(find.text('Juan (yo)'), findsOneWidget);
  });
}
