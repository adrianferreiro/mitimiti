import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

class AuthRepository {
  AuthRepository(this._auth) {
    _auth.onAuthStateChange.listen((state) {
      // Durante la recuperación de contraseña el código ya inicia sesión,
      // pero la app no tiene que pasar a los grupos hasta terminar.
      if (!_recovering) _signedIn.add(state.session != null);
    });
  }

  final GoTrueClient _auth;
  final _signedIn = StreamController<bool>.broadcast();

  bool _recovering = false;

  /// El código de recuperación ya se validó (hay sesión) pero la contraseña
  /// nueva todavía no se guardó.
  bool _recoveryVerified = false;

  bool get isSignedIn => _auth.currentSession != null;

  /// Id del usuario con sesión iniciada, o `null` si no hay sesión.
  String? get currentUserId => _auth.currentUser?.id;

  String? get currentEmail => _auth.currentUser?.email;

  /// Cambia la contraseña del usuario con sesión iniciada (no necesita email).
  Future<void> changePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  /// Emite cada vez que cambia si hay una sesión iniciada.
  Stream<bool> get signedInChanges => _signedIn.stream;

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  /// Crea la cuenta. [name] se guarda en la metadata y el trigger
  /// `handle_new_user` lo usa como nombre del perfil.
  ///
  /// Devuelve `false` si la cuenta quedó pendiente de confirmar por email
  /// (no debería pasar mientras "Confirm email" esté desactivado).
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _guard(
      () =>
          _auth.signUp(email: email, password: password, data: {'name': name}),
    );
    return response.session != null;
  }

  Future<void> signOut() => _auth.signOut();

  /// Manda por email el código para elegir una contraseña nueva. Si no hay
  /// una cuenta con ese email no falla (no se revela qué emails existen).
  Future<void> sendRecoveryCode(String email) {
    _recovering = true;
    return _guard(() => _auth.resetPasswordForEmail(email));
  }

  /// Valida el [code] recibido por email y guarda [newPassword]. Si el código
  /// ya se validó en un intento anterior, solo reintenta guardar la contraseña.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _recovering = true;
    if (!_recoveryVerified) {
      await _guard(
        () =>
            _auth.verifyOTP(email: email, token: code, type: OtpType.recovery),
      );
      _recoveryVerified = true;
    }
    await changePassword(newPassword);
    _recoveryVerified = false;
  }

  /// Cierra la recuperación al salir de su pantalla: si se validó el código
  /// pero no se llegó a guardar la contraseña, cierra esa sesión; si se
  /// guardó, la app pasa a mostrar los grupos.
  Future<void> endRecovery() async {
    if (_recoveryVerified) {
      _recoveryVerified = false;
      await _auth.signOut();
    }
    _recovering = false;
    _signedIn.add(isSignedIn);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AppException(_message(e));
    }
  }

  static String _message(AuthException e) => switch (e.code) {
    'invalid_credentials' => 'Email o contraseña incorrectos.',
    'user_already_exists' ||
    'email_exists' => 'Ya existe una cuenta con ese email.',
    'weak_password' => 'La contraseña es muy débil (mínimo 6 caracteres).',
    'same_password' =>
      'La contraseña nueva tiene que ser distinta a la actual.',
    'email_address_invalid' || 'validation_failed' => 'El email no es válido.',
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' => 'Demasiados intentos. Probá en un rato.',
    'otp_expired' => 'El código es incorrecto o venció. Pedí uno nuevo.',
    'email_address_not_authorized' =>
      'No se pudo enviar el email a esa dirección. Probá más tarde.',
    _ => 'No se pudo completar la operación: ${e.message}',
  };
}
