import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/domain/models/group.dart';
import 'package:mitimiti/ui/groups/groups_screen.dart';

import 'fakes.dart';

const _depto = Group(id: 'g1', name: 'Depto', inviteCode: 'AAA111');
const _viaje = Group(id: 'g2', name: 'Viaje', inviteCode: 'BBB222');

late FakeGroupsRepository _groups;

Future<void> _pump(WidgetTester tester, List<Group> groups) async {
  _groups = FakeGroupsRepository([...groups]);
  await tester.pumpWidget(
    MaterialApp(
      home: GroupsScreen(
        auth: FakeAuthRepository()..currentUserId = 'juan',
        groups: _groups,
        groupData: FakeGroupDataRepository(),
        profile: FakeProfileRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con un solo grupo lo abre directo', (tester) async {
    await _pump(tester, [_depto]);
    expect(find.widgetWithText(AppBar, 'Depto'), findsOneWidget);
    expect(find.text('Saldo'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mis grupos'), findsOneWidget);
  });

  testWidgets('con varios grupos muestra la lista', (tester) async {
    await _pump(tester, [_depto, _viaje]);
    expect(find.text('Mis grupos'), findsOneWidget);
    expect(find.text('Depto'), findsOneWidget);
    expect(find.text('Viaje'), findsOneWidget);
  });

  // Regresión: el diálogo liberaba el TextEditingController mientras su
  // animación de cierre todavía lo usaba.
  testWidgets('crear grupo cierra el diálogo y abre el grupo', (tester) async {
    await _pump(tester, []);
    await tester.tap(find.text('Crear grupo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' Depto ');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_groups.calls, ['create Depto']);
    expect(find.widgetWithText(AppBar, 'Depto'), findsOneWidget);
  });

  testWidgets('cancelar el diálogo no hace nada', (tester) async {
    await _pump(tester, []);
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_groups.calls, isEmpty);
  });

  testWidgets('unirse con código inválido muestra el error', (tester) async {
    await _pump(tester, []);
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz999');
    await tester.tap(find.widgetWithText(FilledButton, 'Unirme'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_groups.calls, ['join zzz999']);
    expect(find.text('Código de invitación inválido'), findsOneWidget);
  });
}
