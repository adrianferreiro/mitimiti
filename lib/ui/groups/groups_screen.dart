import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/auth_repository.dart';
import '../../data/groups_repository.dart';
import '../../domain/models/group.dart';
import 'group_screen.dart';

/// Lista de grupos del usuario, con opciones para crear uno o unirse con un
/// código de invitación.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, required this.auth, required this.groups});

  final AuthRepository auth;
  final GroupsRepository groups;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<List<Group>> _myGroups = widget.groups.myGroups();

  void _reload() => setState(() => _myGroups = widget.groups.myGroups());

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

  void _open(Group group) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => GroupScreen(group: group)));

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
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        void submit() {
          final text = controller.text.trim();
          if (text.isNotEmpty) Navigator.of(context).pop(text);
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: uppercase
                ? TextCapitalization.characters
                : TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label, hintText: hint),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(onPressed: submit, child: Text(action)),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

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
              children: [
                for (final group in groups)
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: Text(group.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(group),
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
