import 'package:flutter/material.dart';

import '../../data/group_data_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/money.dart';
import '../../domain/summary.dart';
import '../category_icon.dart';
import '../format.dart';
import '../theme.dart';
import 'month_selector.dart';

/// Gastos del grupo en el mes elegido, más recientes primero.
class ExpensesTab extends StatelessWidget {
  const ExpensesTab({
    super.key,
    required this.data,
    required this.month,
    required this.onMonthChanged,
    required this.onRefresh,
    required this.onTapExpense,
  });

  final GroupData data;

  /// `null` = todos los meses.
  final DateTime? month;
  final void Function(DateTime?) onMonthChanged;
  final Future<void> Function() onRefresh;
  final void Function(Expense) onTapExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses = expensesInMonth(data.expenses, month);
    final total = expenses.fold(0, (sum, e) => sum + e.amountCents);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        // Deja lugar para que el botón flotante no tape el último gasto.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          MonthSelector(month: month, onChanged: onMonthChanged),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                data.expenses.isEmpty
                    ? 'Todavía no hay gastos.\nTocá "Gasto" para cargar el primero.'
                    : 'No hay gastos en ${formatMonth(month!).toLowerCase()}.',
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            HighlightCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total gastado',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onInk.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCents(total),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.onInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      expenses.length == 1
                          ? '1 gasto'
                          : '${expenses.length} gastos',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Movimientos', style: theme.textTheme.titleMedium),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final e in expenses)
                      ListTile(
                        leading: CategoryAvatar(
                          categoryName: data.categoryName(e.categoryId),
                        ),
                        title: Text(
                          e.description.isEmpty
                              ? data.categoryName(e.categoryId)
                              : e.description,
                        ),
                        subtitle: Text(
                          [
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
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
