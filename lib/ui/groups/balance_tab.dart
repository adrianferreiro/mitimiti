import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/group_data_repository.dart';
import '../../domain/balance.dart';
import '../../domain/models/group.dart';
import '../../domain/models/settlement.dart';
import '../../domain/money.dart';
import '../format.dart';
import '../theme.dart';
import 'members_screen.dart';

/// Quién le debe a quién, cuánto pagó cada uno y los pagos registrados.
class BalanceTab extends StatelessWidget {
  const BalanceTab({
    super.key,
    required this.group,
    required this.data,
    required this.repository,
    required this.currentUserId,
    required this.onChanged,
  });

  final Group group;
  final GroupData data;
  final GroupDataRepository repository;
  final String currentUserId;

  /// Se llama después de registrar o borrar un pago, para recargar.
  final Future<void> Function() onChanged;

  String _name(String userId) => userId == currentUserId
      ? '${data.memberName(userId)} (yo)'
      : data.memberName(userId);

  Future<void> _settle(BuildContext context, Debt debt) async {
    final amountCents = await showDialog<int>(
      context: context,
      builder: (_) => _SettleDialog(
        from: _name(debt.fromUserId),
        to: _name(debt.toUserId),
        suggestedCents: debt.amountCents,
      ),
    );
    if (amountCents == null || !context.mounted) return;
    final now = DateTime.now();
    await _run(
      context,
      () => repository.addSettlement(
        groupId: group.id,
        fromUserId: debt.fromUserId,
        toUserId: debt.toUserId,
        amountCents: amountCents,
        date: DateTime(now.year, now.month, now.day),
      ),
    );
  }

  Future<void> _deleteSettlement(BuildContext context, Settlement s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar este pago?'),
        content: Text(
          '${_name(s.fromUserId)} le pagó ${formatCents(s.amountCents)} '
          'a ${_name(s.toUserId)}. Si lo borrás, esa deuda vuelve a aparecer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, () => repository.deleteSettlement(s.id));
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await onChanged();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo conectar. Revisá tu conexión a internet.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberIds = data.memberIds;
    final balances = netBalances(
      memberIds: memberIds,
      expenses: data.expenses,
      settlements: data.settlements,
    );
    final paid = paidTotals(memberIds: memberIds, expenses: data.expenses);
    final debts = simplifyDebts(balances);

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (memberIds.length < 2) ...[
            const Text(
              'Sos el único miembro del grupo. Invitá a alguien para '
              'repartir los gastos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            InviteCodeCard(inviteCode: group.inviteCode),
            const SizedBox(height: 16),
          ],
          _SectionTitle('Quién le debe a quién'),
          if (debts.isEmpty)
            HighlightCard(
              dark: false,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 28),
                  const SizedBox(width: 12),
                  Text('Están a mano', style: theme.textTheme.titleMedium),
                ],
              ),
            )
          else
            for (final d in debts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HighlightCard(
                  dark: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_name(d.fromUserId)} le debe a ${_name(d.toUserId)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatCents(d.amountCents),
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _settle(context, d),
                            child: const Text('Saldar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 20),
          _SectionTitle('Por persona'),
          Card(
            child: Column(
              children: [
                for (final id in memberIds)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.limeTint,
                      foregroundColor: AppColors.ink,
                      child: Text(
                        data.memberName(id).isEmpty
                            ? '?'
                            : data.memberName(id)[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: Text(_name(id)),
                    subtitle: Text('Pagó ${formatCents(paid[id]!)}'),
                    trailing: _BalanceLabel(cents: balances[id]!),
                  ),
              ],
            ),
          ),
          if (data.settlements.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle('Pagos registrados'),
            Card(
              child: Column(
                children: [
                  for (final s in data.settlements)
                    ListTile(
                      title: Text(
                        '${_name(s.fromUserId)} → ${_name(s.toUserId)}',
                      ),
                      subtitle: Text(formatDate(s.date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatCents(s.amountCents)),
                          IconButton(
                            tooltip: 'Borrar pago',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteSettlement(context, s),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "le deben $X", "debe $X" o "a mano".
class _BalanceLabel extends StatelessWidget {
  const _BalanceLabel({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (cents == 0) return const Text('a mano');
    final owed = cents > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(owed ? 'le deben' : 'debe'),
        Text(
          formatCents(cents.abs()),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: owed ? AppColors.positive : colors.error,
          ),
        ),
      ],
    );
  }
}

/// Confirma el pago; permite cambiar el monto para pagos parciales.
class _SettleDialog extends StatefulWidget {
  const _SettleDialog({
    required this.from,
    required this.to,
    required this.suggestedCents,
  });

  final String from;
  final String to;
  final int suggestedCents;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: formatCents(widget.suggestedCents).replaceFirst(r'$', ''),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(parseCents(_amount.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar pago'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.from} le pagó a ${widget.to}:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: r'$ ',
                helperText: 'Podés cambiarlo si fue un pago parcial',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final cents = parseCents(v ?? '');
                if (cents == null) return 'Ingresá un monto válido';
                if (cents <= 0) return 'El monto tiene que ser mayor a 0';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Registrar')),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
