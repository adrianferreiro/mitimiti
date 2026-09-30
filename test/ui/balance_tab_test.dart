import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/data/group_data_repository.dart';
import 'package:mitimiti/domain/models/group.dart';
import 'package:mitimiti/ui/groups/balance_tab.dart';

import 'fakes.dart';

void main() {
  late FakeGroupDataRepository repo;
  var reloads = 0;

  setUp(() {
    repo = FakeGroupDataRepository();
    reloads = 0;
  });

  Future<void> pump(WidgetTester tester, GroupData data) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BalanceTab(
          group: const Group(id: 'g', name: 'Depto', inviteCode: 'ABC123'),
          data: data,
          repository: repo,
          currentUserId: 'juan',
          onChanged: () async => reloads++,
        ),
      ),
    ),
  );

  testWidgets('sin gastos están a mano', (tester) async {
    await pump(tester, sampleData());
    expect(find.text('Están a mano'), findsOneWidget);
  });

  testWidgets('muestra quién le debe a quién y lo pagado', (tester) async {
    await pump(
      tester,
      sampleData(
        expenses: [
          expense('e1', 'ana', 3000000),
          expense('e2', 'juan', 1000000),
        ],
      ),
    );

    expect(find.text('Juan (yo) le debe a Ana'), findsOneWidget);
    expect(find.text(r'$10.000'), findsWidgets);
    expect(find.text(r'Pagó $30.000'), findsOneWidget);
    expect(find.text(r'Pagó $10.000'), findsOneWidget);
  });

  testWidgets('saldar registra el pago y recarga', (tester) async {
    await pump(tester, sampleData(expenses: [expense('e1', 'ana', 3000000)]));

    await tester.tap(find.text('Saldar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['settle juan ana 1500000']);
    expect(reloads, 1);
  });

  testWidgets('saldar permite un pago parcial', (tester) async {
    await pump(tester, sampleData(expenses: [expense('e1', 'ana', 3000000)]));

    await tester.tap(find.text('Saldar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '5000');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['settle juan ana 500000']);
  });
}
