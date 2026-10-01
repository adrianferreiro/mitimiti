import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/auth_repository.dart';
import '../../data/group_data_repository.dart';
import '../../data/groups_repository.dart';
import '../../data/profile_repository.dart';
import '../../data/push_notifications.dart';
import '../../domain/models/group.dart';
import '../account/account_screen.dart';
import '../dialogs.dart';
import '../theme.dart';
import 'group_screen.dart';

/// Lista de grupos del usuario, con opciones para crear uno o unirse con un
/// código de invitación.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({
    super.key,
    required this.auth,
    required this.groups,
    required this.groupData,
    required this.profile,
    required this.push,
  });

  final AuthRepository auth;
  final GroupsRepository groups;
  final GroupDataRepository groupData;
  final ProfileRepository profile;
  final PushNotifications push;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<List<Group>> _myGroups = widget.groups.myGroups();
  late final StreamSubscription<String> _pushTaps;

  @override
  void initState() {
    super.initState();
    _openInitialGroup();
    _pushTaps = widget.push.openedGroupIds.listen(_openFromPush);
  }

  @override
  void dispose() {
    _pushTaps.cancel();
    super.dispose();
  }

  /// Si la app se abrió tocando una notificación, abre ese grupo. Si no, y
  /// hay un solo grupo (caso típico: la pareja), lo abre directo; volviendo
  /// atrás queda la lista para crear o unirse a otro.
  Future<void> _openInitialGroup() async {
    final pushGroupId = await widget.push.takeInitialGroupId();
    try {
      final groups = await _myGroups;
      if (!mounted) return;
      final fromPush = groups.where((g) => g.id == pushGroupId);
      if (fromPush.isNotEmpty) {
        _open(fromPush.first);
      } else if (groups.length == 1) {
        _open(groups.single);
      }
    } catch (_) {}
  }

  /// Notificación tocada con la app en segundo plano: vuelve a la lista y
  /// abre ese grupo (si ya estaba abierto, se reabre con los datos al día).
  Future<void> _openFromPush(String groupId) async {
    _reload();
    try {
      final groups = await _myGroups;
      final matches = groups.where((g) => g.id == groupId);
      if (!mounted || matches.isEmpty) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      _open(matches.first);
    } catch (_) {}
  }

  void _reload() {
    final future = widget.groups.myGroups();
    // Bloque con llaves: setState no acepta un callback que devuelva Future.
    setState(() {
      _myGroups = future;
    });
  }

  Future<void> _createGroup() async {
    final name = await _askText(
      title: 'Nuevo grupo',
      label: 'Nombre',
      hint: 'Ej: Depto',
      action: 'Crear',
    );
    if (name == null) return;
    await _runAndOpen(() => widget.groups.createGroup(name));
  }

  Future<void> _joinGroup() async {
    final code = await _askText(
      title: 'Unirme a un grupo',
      label: 'Código de invitación',
      hint: 'Ej: A1B2C3',
      action: 'Unirme',
      uppercase: true,
    );
    if (code == null) return;
    await _runAndOpen(() => widget.groups.joinGroup(code));
  }

  Future<void> _runAndOpen(Future<Group> Function() action) async {
    try {
      final group = await action();
      _reload();
      if (mounted) _open(group);
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('No se pudo conectar. Revisá tu conexión a internet.');
    }
  }

  Future<void> _open(Group group) async {
    final userId = widget.auth.currentUserId;
    if (userId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupScreen(
          group: group,
          repository: widget.groupData,
          groups: widget.groups,
          auth: widget.auth,
          profile: widget.profile,
          currentUserId: userId,
        ),
      ),
    );
    // Al volver: el grupo pudo cambiar de nombre o el usuario pudo salir.
    if (mounted) _reload();
  }

  void _openAccount() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AccountScreen(auth: widget.auth, profile: widget.profile),
    ),
  );

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askText({
    required String title,
    required String label,
    required String hint,
    required String action,
    bool uppercase = false,
  }) => showTextPrompt(
    context,
    title: title,
    label: label,
    hint: hint,
    action: action,
    uppercase: uppercase,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis grupos'),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.person_outline),
            onPressed: _openAccount,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<Group>>(
        future: _myGroups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message(
              text: 'No se pudieron cargar tus grupos.',
              actionLabel: 'Reintentar',
              onAction: _reload,
            );
          }
          final groups = snapshot.data!;
          if (groups.isEmpty) {
            return const _Message(
              text:
                  'Todavía no estás en ningún grupo.\n'
                  'Creá uno o unite con el código que te pasaron.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _myGroups;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final group in groups)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: const CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.ink,
                        child: Icon(Icons.group_outlined),
                      ),
                      title: Text(group.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(group),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _joinGroup,
                  icon: const Icon(Icons.login),
                  label: const Text('Unirme'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear grupo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
