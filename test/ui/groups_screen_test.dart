import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/domain/models/group.dart';
import 'package:mitimiti/ui/groups/groups_screen.dart';

import 'fakes.dart';

const _depto = Group(id: 'g1', name: 'Depto', inviteCode: 'AAA111');
const _viaje = Group(id: 'g2', name: 'Viaje', inviteCode: 'BBB222');

Future<void> _pump(WidgetTester tester, List<Group> groups) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GroupsScreen(
        auth: FakeAuthRepository()..currentUserId = 'juan',
        groups: FakeGroupsRepository(groups),
        groupData: FakeGroupDataRepository(),
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
}
