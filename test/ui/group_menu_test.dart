import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/data/group_data_repository.dart';
import 'package:mitimiti/domain/models/group.dart';
import 'package:mitimiti/ui/groups/group_screen.dart';

import 'fakes.dart';

const _depot = Group(id: 'g', name: 'Depot', inviteCode: 'ABC123');

late FakeGroupsRepository _groups;

/// Abre el grupo encima de una pantalla raíz, para poder comprobar que
/// "Salir del grupo" vuelve atrás.
Future<void> _pump(WidgetTester tester, GroupData data) async {
  _groups = FakeGroupsRepository([_depot]);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GroupScreen(
                    group: _depot,
                    repository: FakeGroupDataRepository()..data = data,
                    groups: _groups,
                    auth: FakeAuthRepository()..currentUserId = 'juan',
                    profile: FakeProfileRepository(),
                    currentUserId: 'juan',
                  ),
                ),
              ),
              child: const Text('raíz'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('raíz'));
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('Más opciones'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renombrar actualiza el título', (tester) async {
    await _pump(tester, sampleData());
    await _menu(tester, 'Renombrar grupo');

    await tester.enterText(find.byType(TextField), 'Depto');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(_groups.calls, ['rename g Depto']);
    expect(find.widgetWithText(AppBar, 'Depto'), findsOneWidget);
  });

  testWidgets('no deja salir si tengo gastos en el grupo', (tester) async {
    await _pump(tester, sampleData(expenses: [expense('e1', 'juan', 1000)]));
    await _menu(tester, 'Salir del grupo');

    expect(
      find.text(
        'No podés salir: tenés gastos o pagos registrados en este grupo.',
      ),
      findsOneWidget,
    );
    expect(_groups.calls, isEmpty);
  });

  testWidgets('salir sin movimientos confirma y vuelve atrás', (tester) async {
    await _pump(tester, sampleData(expenses: [expense('e1', 'ana', 1000)]));
    await _menu(tester, 'Salir del grupo');
    await tester.tap(find.widgetWithText(FilledButton, 'Salir'));
    await tester.pumpAndSettle();

    expect(_groups.calls, ['leave g']);
    expect(find.text('raíz'), findsOneWidget);
  });
}
