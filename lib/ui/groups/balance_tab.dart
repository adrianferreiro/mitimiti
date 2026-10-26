import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/group_data_repository.dart';
import '../../domain/balance.dart';
import '../../domain/models/group.dart';
import '../../domain/models/settlement.dart';
import '../../domain/money.dart';
import '../dialogs.dart';
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

  /// Registra un pago: saldando [debt] (total o parcial) o, sin [debt],
  /// eligiendo libremente quién paga y a quién.
  Future<void> _registerPayment(BuildContext context, {Debt? debt}) async {
    final payment = await showDialog<_Payment>(
      context: context,
      builder: (_) => _PaymentDialog(
        // Un pago libre solo entre los que siguen; una deuda puede ser de
        // alguien dado de baja.
        members: [
          for (final m in debt == null ? data.activeMembers : data.members)
            (id: m.userId, name: _name(m.userId)),
        ],
        currentUserId: currentUserId,
        debt: debt,
      ),
    );
    if (payment == null || !context.mounted) return;
    if (debt == null && !await _confirmCredit(context, payment)) return;
    if (!context.mounted) return;
    await _run(
      context,
      () => repository.addSettlement(
        groupId: group.id,
        fromUserId: payment.from,
        toUserId: payment.to,
        amountCents: payment.amountCents,
        date: payment.date,
      ),
    );
  }

  /// Si el pago deja a alguien con saldo a favor (o deuda nueva), pide
  /// confirmación. Al saldar una deuda no hace falta: el diálogo ya limita
  /// el monto.
  Future<bool> _confirmCredit(BuildContext context, _Payment p) async {
    final balances = netBalances(
      memberIds: data.memberIds,
      expenses: data.expenses,
      settlements: data.settlements,
      leftOn: data.leftOn,
    );
    final fromAfter = balances[p.from]! + p.amountCents;
    final toAfter = balances[p.to]! - p.amountCents;
    if (fromAfter <= 0 && toAfter >= 0) return true;
    return confirm(
      context,
      title: '¿Registrar el pago igual?',
      message: fromAfter > 0
          ? 'Con este pago, ${_name(p.from)} pasaría a tener '
                '${formatCents(fromAfter)} a favor.'
          : 'Con este pago, ${_name(p.to)} pasaría a deber '
                '${formatCents(-toAfter)}.',
      action: 'Registrar',
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
      leftOn: data.leftOn,
    );
    final paid = paidTotals(memberIds: memberIds, expenses: data.expenses);
    final debts = simplifyDebts(balances);

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (data.activeMembers.length < 2) ...[
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
                            onPressed: () => _registerPayment(context, debt: d),
                            child: const Text('Saldar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          if (data.activeMembers.length >= 2)
            Center(
              child: TextButton.icon(
                onPressed: () => _registerPayment(context),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Registrar pago'),
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
                      backgroundColor: memberColor(isMe: id == currentUserId),
                      foregroundColor: AppColors.ink,
                      child: Text(
                        data.memberName(id).isEmpty
                            ? '?'
                            : data.memberName(id)[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: Text(_name(id)),
                    subtitle: Text(
                      data.leftOn.containsKey(id)
                          ? 'Pagó ${formatCents(paid[id]!)} · ya no está en '
                                'el grupo'
                          : 'Pagó ${formatCents(paid[id]!)}',
                    ),
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

/// Lo que devuelve [_PaymentDialog].
typedef _Payment = ({String from, String to, int amountCents, DateTime date});

/// Registra un pago. Con [debt], salda esa deuda (total o parcial, nunca más
/// de lo que se debe); sin [debt], se elige quién paga, a quién y cuánto.
class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.members,
    required this.currentUserId,
    this.debt,
  });

  final List<({String id, String name})> members;
  final String currentUserId;
  final Debt? debt;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late String _from;
  late String _to;
  var _partial = false;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    if (debt != null) {
      _from = debt.fromUserId;
      _to = debt.toUserId;
    } else {
      final isMember = widget.members.any((m) => m.id == widget.currentUserId);
      _from = isMember ? widget.currentUserId : widget.members.first.id;
      _to = widget.members.firstWhere((m) => m.id != _from).id;
    }
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _name(String id) => widget.members.firstWhere((m) => m.id == id).name;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final debt = widget.debt;
    final amountCents = debt != null && !_partial
        ? debt.amountCents
        : parseCents(_amount.text)!;
    Navigator.of(context).pop<_Payment>((
      from: _from,
      to: _to,
      amountCents: amountCents,
      date: _date,
    ));
  }

  Widget _memberDropdown({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    FormFieldValidator<String>? validator,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final m in widget.members)
        DropdownMenuItem(
          value: m.id,
          child: Text(m.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) => setState(() => onChanged(v!)),
    validator: validator,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debt = widget.debt;
    return AlertDialog(
      title: const Text('Registrar pago'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (debt != null) ...[
                Text('${_name(_from)} le debe a ${_name(_to)}'),
                const SizedBox(height: 4),
                Text(
                  formatCents(debt.amountCents),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Total')),
                    ButtonSegment(value: true, label: Text('Parcial')),
                  ],
                  selected: {_partial},
                  onSelectionChanged: (s) => setState(() => _partial = s.first),
                ),
              ] else ...[
                _memberDropdown(
                  label: 'Pagó',
                  value: _from,
                  onChanged: (v) => _from = v,
                ),
                const SizedBox(height: 16),
                _memberDropdown(
                  label: 'A',
                  value: _to,
                  onChanged: (v) => _to = v,
                  validator: (v) =>
                      v == _from ? 'Tiene que ser otra persona' : null,
                ),
              ],
              if (debt == null || _partial) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  autofocus: debt != null,
                  decoration: InputDecoration(
                    labelText: debt != null ? 'Monto pagado' : 'Monto',
                    prefixText: r'$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final cents = parseCents(v ?? '');
                    if (cents == null) return 'Ingresá un monto válido';
                    if (cents <= 0) return 'El monto tiene que ser mayor a 0';
                    if (debt != null && cents > debt.amountCents) {
                      return 'No puede ser mayor a '
                          '${formatCents(debt.amountCents)}';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(formatDate(_date)),
                ),
              ),
            ],
          ),
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
