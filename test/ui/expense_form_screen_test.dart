import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/domain/models/expense.dart';
import 'package:mitimiti/ui/expenses/expense_form_screen.dart';

import 'fakes.dart';

void main() {
  late FakeGroupDataRepository repo;

  setUp(() => repo = FakeGroupDataRepository());

  Future<void> pump(WidgetTester tester, {Expense? editing}) =>
      tester.pumpWidget(
        MaterialApp(
          home: ExpenseFormScreen(
            repository: repo,
            groupId: 'g',
            data: sampleData(),
            currentUserId: 'juan',
            expense: editing,
          ),
        ),
      );

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('valida monto y categoría', (tester) async {
    await pump(tester);
    await tester.enterText(field('Monto'), 'abc');
    await tester.tap(find.text('Agregar gasto'));
    await tester.pump();

    expect(find.text('Ingresá un monto válido'), findsOneWidget);
    expect(find.text('Elegí una categoría'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('carga un gasto nuevo en centavos, pagado por mí', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(field('Monto'), '12.500,50');
    await tester.enterText(field('Descripción (opcional)'), ' Compra ');
    await tester.tap(find.text('Categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Servicios').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar gasto'));
    await tester.pump();

    final now = DateTime.now();
    expect(repo.calls, [
      'add g juan 1250050 serv "Compra" ${now.year}-${now.month}-${now.day}',
    ]);
  });

  testWidgets('edita un gasto existente con sus valores', (tester) async {
    await pump(tester, editing: expense('e1', 'ana', 350000, desc: 'Luz'));
    expect(find.text('Editar gasto'), findsOneWidget);
    expect(find.text('3.500'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();

    expect(repo.calls, ['update e1 ana 350000 super "Luz"']);
  });

  testWidgets('borra con confirmación', (tester) async {
    await pump(tester, editing: expense('e1', 'ana', 350000));
    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['delete e1']);
  });
}
