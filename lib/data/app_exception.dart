/// Error esperable (credenciales inválidas, código inexistente, etc.) con un
/// mensaje listo para mostrarle al usuario.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
