import 'package:flutter/material.dart';

import '../../domain/summary.dart';
import '../format.dart';

/// "‹ Septiembre 2026 ›" con opción de ver todos los meses juntos.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
  });

  /// `null` = todos los meses.
  final DateTime? month;
  final void Function(DateTime?) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final month = this.month;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: month == null
                ? null
                : () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: Text(
              month == null ? 'Todos los meses' : formatMonth(month),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: month == null
                ? null
                : () => onChanged(DateTime(month.year, month.month + 1)),
          ),
          TextButton(
            onPressed: () =>
                onChanged(month == null ? monthOf(DateTime.now()) : null),
            child: Text(month == null ? 'Por mes' : 'Ver todo'),
          ),
        ],
      ),
    );
  }
}
