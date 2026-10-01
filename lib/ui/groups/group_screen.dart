import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/group_data_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/group.dart';
import '../../domain/summary.dart';
import '../expenses/expense_form_screen.dart';
import 'balance_tab.dart';
import 'expenses_tab.dart';
import 'members_screen.dart';
import 'summary_tab.dart';

/// Un grupo: pestañas de gastos, resumen y saldo, y acceso a los miembros.
///
/// Se mantiene al día solo: escucha cambios en vivo y recarga al volver a la
/// app desde segundo plano.
class GroupScreen extends StatefulWidget {
  const GroupScreen({
    super.key,
    required this.group,
    required this.repository,
    required this.currentUserId,
  });

  final Group group;
  final GroupDataRepository repository;
  final String currentUserId;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late Future<GroupData> _data = widget.repository.load(widget.group.id);

  /// Lo último que cargó bien, para no vaciar la pantalla mientras recarga.
  GroupData? _last;

  /// Mes que muestran Gastos y Resumen; `null` = todos. El saldo siempre es
  /// de todo el historial.
  DateTime? _month = monthOf(DateTime.now());

  late final void Function() _unwatch;
  late final AppLifecycleListener _lifecycle;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _unwatch = widget.repository.watch(widget.group.id, _scheduleReload);
    _lifecycle = AppLifecycleListener(onResume: _reload);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _unwatch();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Los cambios en vivo suelen llegar en ráfaga (p. ej. un gasto y su
  /// update): se agrupan en una sola recarga.
  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  Future<void> _reload() {
    if (!mounted) return Future.value();
    final future = widget.repository.load(widget.group.id);
    // Bloque con llaves: setState no acepta un callback que devuelva Future.
    setState(() {
      _data = future;
    });
    return future.then((_) {}, onError: (_) {});
  }

  void _setMonth(DateTime? month) => setState(() => _month = month);

  Future<void> _openExpenseForm(GroupData data, {Expense? expense}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(
          repository: widget.repository,
          groupId: widget.group.id,
          data: data,
          currentUserId: widget.currentUserId,
          expense: expense,
        ),
      ),
    );
    if (changed == true) await _reload();
  }

  void _openMembers(GroupData data) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MembersScreen(
        group: widget.group,
        members: data.members,
        currentUserId: widget.currentUserId,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasData) _last = snapshot.data;
        final data = _last;
        final loading = snapshot.connectionState != ConnectionState.done;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.group.name),
              actions: [
                IconButton(
                  tooltip: 'Miembros e invitación',
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: data == null ? null : () => _openMembers(data),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Gastos'),
                  Tab(text: 'Resumen'),
                  Tab(text: 'Saldo'),
                ],
              ),
            ),
            floatingActionButton: data == null
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _openExpenseForm(data),
                    icon: const Icon(Icons.add),
                    label: const Text('Gasto'),
                  ),
            body: data == null
                ? (snapshot.hasError
                      ? _LoadError(onRetry: _reload)
                      : const Center(child: CircularProgressIndicator()))
                : Column(
                    children: [
                      if (loading) const LinearProgressIndicator(),
                      if (snapshot.hasError && !loading)
                        MaterialBanner(
                          content: const Text(
                            'No se pudo actualizar. Mostrando lo último cargado.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: _reload,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            ExpensesTab(
                              data: data,
                              month: _month,
                              onMonthChanged: _setMonth,
                              onRefresh: _reload,
                              onTapExpense: (e) =>
                                  _openExpenseForm(data, expense: e),
                            ),
                            SummaryTab(
                              data: data,
                              month: _month,
                              onMonthChanged: _setMonth,
                              currentUserId: widget.currentUserId,
                              onRefresh: _reload,
                            ),
                            BalanceTab(
                              group: widget.group,
                              data: data,
                              repository: widget.repository,
                              currentUserId: widget.currentUserId,
                              onChanged: _reload,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudo cargar el grupo.'),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
