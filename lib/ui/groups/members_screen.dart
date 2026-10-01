import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/group.dart';
import '../../domain/models/member.dart';
import '../theme.dart';

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
    return HighlightCard(
      child: Column(
        children: [
          Text(
            'Código de invitación',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.onInk,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            inviteCode,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.lime,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pasale este código a quien quieras sumar al grupo. '
            'Lo ingresa en "Unirme".',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onInk.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.ink,
            ),
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar código'),
          ),
        ],
      ),
    );
  }
}
