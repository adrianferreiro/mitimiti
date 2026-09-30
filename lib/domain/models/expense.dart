/// Un gasto pagado por un miembro del grupo, repartido en partes iguales
/// entre todos los miembros.
class Expense {
  Expense({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.amountCents,
    required this.categoryId,
    required this.date,
    required this.createdBy,
    this.description = '',
  }) {
    if (amountCents <= 0) {
      throw ArgumentError.value(amountCents, 'amountCents', 'debe ser > 0');
    }
  }

  final String id;
  final String groupId;

  /// Id del usuario que pagó.
  final String paidBy;

  /// Monto en centavos de ARS.
  final int amountCents;

  final String categoryId;
  final String description;
  final DateTime date;

  /// Id del usuario que cargó el gasto (puede no ser quien pagó).
  final String createdBy;
}
