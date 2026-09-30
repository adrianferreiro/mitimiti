import 'package:flutter/material.dart';

import '../../data/group_data_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/money.dart';
import '../format.dart';

/// Lista de gastos del grupo, más recientes primero.
class ExpensesTab extends StatelessWidget {
  const ExpensesTab({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onTapExpense,
  });

  final GroupData data;
  final Future<void> Function() onRefresh;
  final void Function(Expense) onTapExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses = data.expenses;
    final total = expenses.fold(0, (sum, e) => sum + e.amountCents);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        // Deja lugar para que el botón flotante no tape el último gasto.
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Todavía no hay gastos.\nTocá "Gasto" para cargar el primero.',
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            ListTile(
              title: Text('Total gastado', style: theme.textTheme.titleMedium),
              trailing: Text(
                formatCents(total),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            for (final e in expenses)
              ListTile(
                title: Text(
                  e.description.isEmpty
                      ? data.categoryName(e.categoryId)
                      : e.description,
                ),
                subtitle: Text(
                  [
                    if (e.description.isNotEmpty)
                      data.categoryName(e.categoryId),
                    'Pagó ${data.memberName(e.paidBy)}',
                    formatDate(e.date),
                  ].join(' · '),
                ),
                trailing: Text(
                  formatCents(e.amountCents),
                  style: theme.textTheme.titleSmall,
                ),
                onTap: () => onTapExpense(e),
              ),
          ],
        ],
      ),
    );
  }
}
