import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/auth_repository.dart';
import '../../data/group_data_repository.dart';
import '../../data/groups_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/group.dart';
import '../../domain/summary.dart';
import '../account/account_screen.dart';
import '../dialogs.dart';
import '../expenses/expense_form_screen.dart';
import '../theme.dart';
import 'balance_tab.dart';
import 'categories_screen.dart';
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
    required this.groups,
    required this.auth,
    required this.profile,
    required this.currentUserId,
  });

  final Group group;
  final GroupDataRepository repository;
  final GroupsRepository groups;
  final AuthRepository auth;
  final ProfileRepository profile;
  final String currentUserId;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  /// Copia local para reflejar un renombre sin volver a la lista.
  late Group _group = widget.group;

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

  Future<void> _onMenu(_MenuAction action, GroupData? data) async {
    switch (action) {
      case _MenuAction.rename:
        await _rename();
      case _MenuAction.categories:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoriesScreen(
              groupId: _group.id,
              repository: widget.repository,
            ),
          ),
        );
        await _reload();
      case _MenuAction.account:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                AccountScreen(auth: widget.auth, profile: widget.profile),
          ),
        );
        // Puede haber cambiado el nombre propio, que se ve en todo el grupo.
        await _reload();
      case _MenuAction.leave:
        await _leave(data);
    }
  }

  Future<void> _rename() async {
    final name = await showTextPrompt(
      context,
      title: 'Renombrar grupo',
      label: 'Nombre',
      action: 'Guardar',
      initialValue: _group.name,
    );
    if (name == null || name == _group.name) return;
    try {
      final updated = await widget.groups.renameGroup(_group.id, name);
      if (mounted) setState(() => _group = updated);
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('No se pudo conectar. Revisá tu conexión a internet.');
    }
  }

  Future<void> _leave(GroupData? data) async {
    final me = widget.currentUserId;
    // Mismo chequeo que hace la base (FKs a la membresía), pero antes de
    // preguntar, para explicar por qué no se puede.
    final hasMovements =
        data != null &&
        (data.expenses.any((e) => e.paidBy == me) ||
            data.settlements.any(
              (s) => s.fromUserId == me || s.toUserId == me,
            ));
    if (hasMovements) {
      _showError(
        'No podés salir: tenés gastos o pagos registrados en este grupo.',
      );
      return;
    }
    final yes = await confirm(
      context,
      title: '¿Salir de "${_group.name}"?',
      message:
          'Vas a dejar de ver sus gastos. Para volver vas a necesitar el '
          'código de invitación.',
      action: 'Salir',
    );
    if (!yes) return;
    try {
      await widget.groups.leaveGroup(_group.id);
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('No se pudo conectar. Revisá tu conexión a internet.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openMembers(GroupData data) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MembersScreen(
        group: _group,
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
              title: Text(_group.name),
              actions: [
                IconButton(
                  tooltip: 'Miembros e invitación',
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: data == null ? null : () => _openMembers(data),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<_MenuAction>(
                  tooltip: 'Más opciones',
                  icon: const Icon(Icons.more_horiz),
                  position: PopupMenuPosition.under,
                  onSelected: (action) => _onMenu(action, data),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _MenuAction.rename,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Renombrar grupo'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.categories,
                      child: ListTile(
                        leading: Icon(Icons.category_outlined),
                        title: Text('Categorías'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.account,
                      child: ListTile(
                        leading: Icon(Icons.person_outline),
                        title: Text('Mi cuenta'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.leave,
                      child: ListTile(
                        leading: Icon(Icons.exit_to_app),
                        title: Text('Salir del grupo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const TabBar(
                      tabs: [
                        Tab(text: 'Gastos', height: 44),
                        Tab(text: 'Resumen', height: 44),
                        Tab(text: 'Saldo', height: 44),
                      ],
                    ),
                  ),
                ),
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
                              group: _group,
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

enum _MenuAction { rename, categories, account, leave }
