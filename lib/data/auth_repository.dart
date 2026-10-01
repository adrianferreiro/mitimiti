import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  bool get isSignedIn => _auth.currentSession != null;

  /// Id del usuario con sesión iniciada, o `null` si no hay sesión.
  String? get currentUserId => _auth.currentUser?.id;

  String? get currentEmail => _auth.currentUser?.email;

  /// Cambia la contraseña del usuario con sesión iniciada (no necesita email).
  Future<void> changePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  /// Emite cada vez que cambia si hay una sesión iniciada.
  Stream<bool> get signedInChanges =>
      _auth.onAuthStateChange.map((state) => state.session != null);

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
    _ => 'No se pudo completar la operación: ${e.message}',
  };
}
