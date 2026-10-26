/// Un miembro de un grupo.
class Member {
  const Member({required this.userId, required this.displayName, this.leftOn});

  final String userId;
  final String displayName;

  /// Día en que dejó el grupo (p. ej. al eliminar su cuenta), o `null` si
  /// sigue. Participa de los gastos hasta ese día inclusive.
  final DateTime? leftOn;

  bool get isActive => leftOn == null;

  /// Si un gasto de [date] se reparte también con este miembro.
  bool participatesOn(DateTime date) =>
      leftOn == null || !date.isAfter(leftOn!);
}
