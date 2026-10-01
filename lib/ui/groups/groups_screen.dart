import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/auth_repository.dart';
import '../../data/group_data_repository.dart';
import '../../data/groups_repository.dart';
import '../../domain/models/group.dart';
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
  });

  final AuthRepository auth;
  final GroupsRepository groups;
  final GroupDataRepository groupData;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<List<Group>> _myGroups = widget.groups.myGroups();

  @override
  void initState() {
    super.initState();
    // Caso típico: un solo grupo (la pareja). Se abre directo; volviendo
    // atrás queda la lista para crear o unirse a otro.
    _myGroups.then((groups) {
      if (mounted && groups.length == 1) _open(groups.single);
    }, onError: (_) {});
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

  void _open(Group group) {
    final userId = widget.auth.currentUserId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupScreen(
          group: group,
          repository: widget.groupData,
          currentUserId: userId,
        ),
      ),
    );
  }

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
  }) => showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      label: label,
      hint: hint,
      action: action,
      uppercase: uppercase,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis grupos'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: widget.auth.signOut,
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
                        backgroundColor: AppColors.lime,
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

/// Diálogo con un campo de texto. Es dueño de su controller: si lo liberara
/// quien abre el diálogo apenas vuelve `showDialog`, la animación de cierre
/// todavía lo usaría (y explota con "used after being disposed").
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.action,
    required this.uppercase,
  });

  final String title;
  final String label;
  final String hint;
  final String action;
  final bool uppercase;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.uppercase
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
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
