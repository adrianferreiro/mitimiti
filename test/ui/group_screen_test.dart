import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/domain/models/group.dart';
import 'package:mitimiti/ui/groups/group_screen.dart';

import 'fakes.dart';

void main() {
  // Regresión: _reload hacía `setState(() => _data = future)`, que devuelve
  // un Future y setState lo rechaza.
  testWidgets('guardar un gasto vuelve al grupo y recarga sin errores', (
    tester,
  ) async {
    final repo = FakeGroupDataRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: GroupScreen(
          group: const Group(id: 'g', name: 'Depto', inviteCode: 'ABC123'),
          repository: repo,
          groups: FakeGroupsRepository([]),
          auth: FakeAuthRepository()..currentUserId = 'juan',
          profile: FakeProfileRepository(),
          currentUserId: 'juan',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '100');
    await tester.tap(find.text('Categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Servicios').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar gasto'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repo.calls.single, startsWith('add g juan 10000 serv'));
    expect(find.widgetWithText(AppBar, 'Depto'), findsOneWidget);
  });
}
