/// Un pago entre miembros para saldar deuda. No borra gastos: se suma al
/// cálculo del balance.
class Settlement {
  Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountCents,
    required this.date,
  }) {
    if (amountCents <= 0) {
      throw ArgumentError.value(amountCents, 'amountCents', 'debe ser > 0');
    }
    if (fromUserId == toUserId) {
      throw ArgumentError('Un pago no puede ser de un usuario a sí mismo');
    }
  }

  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;

  /// Monto en centavos de ARS.
  final int amountCents;

  final DateTime date;
}
