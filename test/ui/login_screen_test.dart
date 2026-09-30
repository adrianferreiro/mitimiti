import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/data/app_exception.dart';
import 'package:mitimiti/data/auth_repository.dart';
import 'package:mitimiti/ui/auth/login_screen.dart';

class FakeAuthRepository implements AuthRepository {
  final calls = <String>[];
  AppException? failWith;

  @override
  bool get isSignedIn => false;

  @override
  String? get currentUserId => null;

  @override
  Stream<bool> get signedInChanges => const Stream.empty();

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn $email $password');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    calls.add('signUp $email $password $name');
    if (failWith != null) throw failWith!;
    return true;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  Future<void> pump(WidgetTester tester) =>
      tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('ingresa con email recortado y contraseña', (tester) async {
    await pump(tester);
    await tester.enterText(field('Email'), '  ana@mail.com ');
    await tester.enterText(field('Contraseña'), 'secreta1');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(auth.calls, ['signIn ana@mail.com secreta1']);
  });

  testWidgets('no envía si el formulario es inválido', (tester) async {
    await pump(tester);
    await tester.enterText(field('Email'), 'sin-arroba');
    await tester.enterText(field('Contraseña'), '123');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresá un email válido'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('registro pide nombre y lo envía', (tester) async {
    await pump(tester);
    await tester.tap(find.text('¿No tenés cuenta? Registrate'));
    await tester.pump();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();
    expect(find.text('Ingresá tu nombre'), findsOneWidget);

    await tester.enterText(field('Nombre'), ' Ana ');
    await tester.enterText(field('Email'), 'ana@mail.com');
    await tester.enterText(field('Contraseña'), 'secreta1');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(auth.calls, ['signUp ana@mail.com secreta1 Ana']);
  });

  testWidgets('muestra el mensaje de error del repositorio', (tester) async {
    auth.failWith = const AppException('Email o contraseña incorrectos.');
    await pump(tester);
    await tester.enterText(field('Email'), 'ana@mail.com');
    await tester.enterText(field('Contraseña'), 'equivocada');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
  });
}
