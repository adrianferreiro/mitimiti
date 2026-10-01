import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/ui/account/account_screen.dart';
import 'package:mitimiti/ui/groups/categories_screen.dart';

import 'fakes.dart';

void main() {
  group('AccountScreen', () {
    late FakeAuthRepository auth;
    late FakeProfileRepository profile;

    setUp(() {
      auth = FakeAuthRepository();
      profile = FakeProfileRepository();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountScreen(auth: auth, profile: profile),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra nombre y email, y cambia el nombre', (tester) async {
      await pump(tester);
      expect(find.text('Juan'), findsOneWidget);
      expect(find.text('juan@mail.com'), findsOneWidget);

      await tester.tap(find.text('Cambiar nombre'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Juancho');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(profile.calls, ['updateName Juancho']);
      expect(find.text('Juancho'), findsOneWidget);
    });

    testWidgets('cambiar contraseña pide repetirla', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nueva123');
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'otra456');
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nueva123');
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nueva123');
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['changePassword nueva123']);
    });

    testWidgets('cerrar sesión pide confirmación', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['signOut']);
    });
  });

  group('CategoriesScreen', () {
    late FakeGroupDataRepository repo;

    Future<void> pump(WidgetTester tester) async {
      repo = FakeGroupDataRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesScreen(groupId: 'g', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('agrega, renombra y borra', (tester) async {
      await pump(tester);
      expect(find.text('Supermercado'), findsOneWidget);

      await tester.tap(find.text('Categoría'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mascotas');
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Servicios'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Luz y gas');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Borrar Supermercado'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.pumpAndSettle();

      expect(repo.calls, [
        'addCategory g Mascotas',
        'renameCategory serv Luz y gas',
        'deleteCategory super',
      ]);
    });
  });
}
