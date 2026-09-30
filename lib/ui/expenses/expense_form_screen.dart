import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/group_data_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/money.dart';
import '../format.dart';

/// Alta o edición de un gasto. Hace `pop(true)` si guardó o borró algo.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.repository,
    required this.groupId,
    required this.data,
    required this.currentUserId,
    this.expense,
  });

  final GroupDataRepository repository;
  final String groupId;
  final GroupData data;
  final String currentUserId;

  /// El gasto a editar, o `null` para cargar uno nuevo.
  final Expense? expense;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.expense == null
        ? ''
        : formatCents(widget.expense!.amountCents).replaceFirst(r'$', ''),
  );
  late final _description = TextEditingController(
    text: widget.expense?.description ?? '',
  );
  late String? _categoryId = widget.expense?.categoryId;
  late String _paidBy = widget.expense?.paidBy ?? _defaultPayer();
  late DateTime _date = widget.expense?.date ?? _today();

  bool _busy = false;

  bool get _editing => widget.expense != null;

  String _defaultPayer() {
    final ids = widget.data.memberIds;
    return ids.contains(widget.currentUserId)
        ? widget.currentUserId
        : ids.first;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: _today().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amountCents = parseCents(_amount.text)!;
    final description = _description.text.trim();
    await _run(() {
      if (_editing) {
        return widget.repository.updateExpense(
          expenseId: widget.expense!.id,
          paidBy: _paidBy,
          amountCents: amountCents,
          categoryId: _categoryId!,
          description: description,
          date: _date,
        );
      }
      return widget.repository.addExpense(
        groupId: widget.groupId,
        paidBy: _paidBy,
        amountCents: amountCents,
        categoryId: _categoryId!,
        description: description,
        date: _date,
      );
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar este gasto?'),
        content: const Text('Se recalcula el saldo del grupo.'),
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
    if (confirmed != true) return;
    await _run(() => widget.repository.deleteExpense(widget.expense!.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('No se pudo conectar. Revisá tu conexión a internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar gasto' : 'Nuevo gasto'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amount,
              autofocus: !_editing,
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: r'$ ',
                border: OutlineInputBorder(),
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
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej: compra del mes',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in data.categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Elegí una categoría' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paidBy,
              decoration: const InputDecoration(
                labelText: 'Pagó',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final m in data.members)
                  DropdownMenuItem(
                    value: m.userId,
                    child: Text(
                      m.userId == widget.currentUserId
                          ? '${m.displayName} (yo)'
                          : m.displayName,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _paidBy = v!),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(formatDate(_date)),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editing ? 'Guardar cambios' : 'Agregar gasto'),
            ),
          ],
        ),
      ),
    );
  }
}
