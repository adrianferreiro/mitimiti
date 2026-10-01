import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notificaciones push (FCM). Guarda el token del dispositivo para el usuario
/// con sesión iniciada (tabla `device_tokens`, vía RPC) y avisa qué grupo
/// abrir cuando el usuario toca una notificación.
///
/// Los avisos los manda la Edge Function `notify` (supabase/functions/notify).
/// Si algo de esto falla la app sigue funcionando igual, así que los errores
/// se ignoran.
class PushNotifications {
  PushNotifications(this._db, this._messaging);

  final SupabaseClient _db;
  final FirebaseMessaging _messaging;

  StreamSubscription<String>? _tokenRefresh;
  bool _initialMessageUsed = false;

  /// Pide permiso para notificar (iOS y Android 13+) y registra el token.
  Future<void> register() async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _token();
      if (token == null) return;
      await _save(token);
      _tokenRefresh ??= _messaging.onTokenRefresh.listen(
        (token) => _save(token).catchError((_) {}),
      );
    } catch (_) {}
  }

  /// Llamar antes de cerrar sesión (después ya no hay permiso para borrarlo).
  Future<void> unregister() async {
    try {
      await _tokenRefresh?.cancel();
      _tokenRefresh = null;
      final token = await _token();
      if (token == null) return;
      await _db.rpc<void>(
        'unregister_device_token',
        params: {'device_token': token},
      );
    } catch (_) {}
  }

  /// Grupo de la notificación con la que se abrió la app estando cerrada.
  /// Devuelve algo una sola vez por ejecución.
  Future<String?> takeInitialGroupId() async {
    if (_initialMessageUsed) return null;
    _initialMessageUsed = true;
    try {
      return _groupId(await _messaging.getInitialMessage());
    } catch (_) {
      return null;
    }
  }

  /// Grupos de las notificaciones que se tocan con la app en segundo plano.
  Stream<String> get openedGroupIds => FirebaseMessaging.onMessageOpenedApp
      .map(_groupId)
      .where((id) => id != null)
      .cast<String>();

  Future<void> _save(String token) => _db.rpc<void>(
    'register_device_token',
    params: {
      'device_token': token,
      'device_platform': Platform.isIOS ? 'ios' : 'android',
    },
  );

  /// En iOS el token de FCM necesita el de APNs, que puede tardar un poco en
  /// llegar después de dar permiso.
  Future<String?> _token() async {
    if (Platform.isIOS) {
      for (var i = 0; i < 10; i++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return _messaging.getToken();
  }

  static String? _groupId(RemoteMessage? message) =>
      message?.data['group_id'] as String?;
}
