/// Qué notificaciones push quiere recibir el usuario. Por defecto, todas.
class NotificationPrefs {
  const NotificationPrefs({
    this.expenseNew = true,
    this.expenseChanged = true,
    this.settlement = true,
    this.memberJoined = true,
  });

  /// Otro miembro cargó un gasto.
  final bool expenseNew;

  /// Otro miembro editó o borró un gasto.
  final bool expenseChanged;

  /// Alguien registró un pago que te involucra.
  final bool settlement;

  /// Alguien se unió al grupo.
  final bool memberJoined;

  NotificationPrefs copyWith({
    bool? expenseNew,
    bool? expenseChanged,
    bool? settlement,
    bool? memberJoined,
  }) => NotificationPrefs(
    expenseNew: expenseNew ?? this.expenseNew,
    expenseChanged: expenseChanged ?? this.expenseChanged,
    settlement: settlement ?? this.settlement,
    memberJoined: memberJoined ?? this.memberJoined,
  );
}
