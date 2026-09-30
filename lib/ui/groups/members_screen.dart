import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/group.dart';
import '../../domain/models/member.dart';

/// Miembros del grupo y código para invitar a otros.
class MembersScreen extends StatelessWidget {
  const MembersScreen({
    super.key,
    required this.group,
    required this.members,
    required this.currentUserId,
  });

  final Group group;
  final List<Member> members;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Miembros')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InviteCodeCard(inviteCode: group.inviteCode),
          const SizedBox(height: 16),
          for (final m in members)
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  m.displayName.isEmpty ? '?' : m.displayName[0].toUpperCase(),
                ),
              ),
              title: Text(
                m.userId == currentUserId
                    ? '${m.displayName} (yo)'
                    : m.displayName,
              ),
            ),
        ],
      ),
    );
  }
}

class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({super.key, required this.inviteCode});

  final String inviteCode;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Código de invitación', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              inviteCode,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pasale este código a quien quieras sumar al grupo. '
              'Lo ingresa en "Unirme".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar código'),
            ),
          ],
        ),
      ),
    );
  }
}
