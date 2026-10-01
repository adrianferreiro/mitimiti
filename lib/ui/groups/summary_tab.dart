import 'package:flutter/material.dart';

import '../../data/group_data_repository.dart';
import '../../domain/balance.dart';
import '../../domain/money.dart';
import '../../domain/summary.dart';
import '../theme.dart';
import 'month_selector.dart';

/// Cuánto se gastó en el mes elegido, por categoría y por persona.
class SummaryTab extends StatelessWidget {
  const SummaryTab({
    super.key,
    required this.data,
    required this.month,
    required this.onMonthChanged,
    required this.currentUserId,
    required this.onRefresh,
  });

  final GroupData data;

  /// `null` = todos los meses.
  final DateTime? month;
  final void Function(DateTime?) onMonthChanged;
  final String currentUserId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses = expensesInMonth(data.expenses, month);
    final total = expenses.fold(0, (sum, e) => sum + e.amountCents);
    final byCategory = totalsByCategory(expenses);
    final byMember = paidTotals(memberIds: data.memberIds, expenses: expenses);
    final members = data.memberIds.length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          MonthSelector(month: month, onChanged: onMonthChanged),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No hay gastos en este período.',
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            HighlightCard(
              dark: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total gastado', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    formatCents(total),
                    style: theme.textTheme.headlineMedium,
                  ),
                  if (members > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${formatCents(total ~/ members)} por persona',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _Section(
              title: 'Por categoría',
              rows: [
                for (final e in byCategory)
                  _Row(
                    label: data.categoryName(e.key),
                    cents: e.value,
                    total: total,
                  ),
              ],
            ),
            _Section(
              title: 'Pagado por cada uno',
              rows: [
                for (final id in data.memberIds)
                  _Row(
                    label: id == currentUserId
                        ? '${data.memberName(id)} (yo)'
                        : data.memberName(id),
                    cents: byMember[id]!,
                    total: total,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta, monto, porcentaje del total y una barra proporcional.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.cents, required this.total});

  final String label;
  final int cents;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total == 0 ? 0.0 : cents / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '${formatCents(cents)}  ·  ${(fraction * 100).round()}%',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: fraction, minHeight: 6),
          ),
        ],
      ),
    );
  }
}
