class Group {
  const Group({required this.id, required this.name, required this.inviteCode});

  final String id;
  final String name;

  /// Código de 6 caracteres para que otros se sumen al grupo.
  final String inviteCode;
}
