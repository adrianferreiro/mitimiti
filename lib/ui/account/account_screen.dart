import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/auth_repository.dart';
import '../../data/profile_repository.dart';
import '../dialogs.dart';
import '../theme.dart';

/// Nombre, contraseña y cierre de sesión.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.auth, required this.profile});

  final AuthRepository auth;
  final ProfileRepository profile;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<String> _name = widget.profile.myDisplayName();

  Future<void> _changeName(String current) async {
    final name = await showTextPrompt(
      context,
      title: 'Tu nombre',
      label: 'Nombre',
      action: 'Guardar',
      initialValue: current,
    );
    if (name == null || name == current) return;
    final ok = await _run(() => widget.profile.updateDisplayName(name));
    if (!ok || !mounted) return;
    final future = widget.profile.myDisplayName();
    setState(() {
      _name = future;
    });
  }

  Future<void> _changePassword() async {
    final password = await showTextPrompt(
      context,
      title: 'Nueva contraseña',
      label: 'Contraseña nueva',
      action: 'Siguiente',
      obscure: true,
    );
    if (password == null || !mounted) return;
    if (password.length < 6) {
      _show('La contraseña tiene que tener al menos 6 caracteres.');
      return;
    }
    final repeated = await showTextPrompt(
      context,
      title: 'Repetí la contraseña',
      label: 'Contraseña nueva',
      action: 'Cambiar',
      obscure: true,
    );
    if (repeated == null) return;
    if (repeated != password) {
      _show('Las contraseñas no coinciden.');
      return;
    }
    if (await _run(() => widget.auth.changePassword(password))) {
      _show('Contraseña actualizada.');
    }
  }

  Future<void> _signOut() async {
    final yes = await confirm(
      context,
      title: '¿Cerrar sesión?',
      message: 'Para volver a entrar vas a necesitar tu email y contraseña.',
      action: 'Cerrar sesión',
    );
    if (!yes || !mounted) return;
    // Volver a la raíz antes de salir: la raíz pasa a mostrar el login y no
    // tienen que quedar pantallas del grupo apiladas encima.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await widget.auth.signOut();
  }

  /// Corre [action] y muestra el error si falla. Devuelve si salió bien.
  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on AppException catch (e) {
      _show(e.message);
    } catch (_) {
      _show('No se pudo conectar. Revisá tu conexión a internet.');
    }
    return false;
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: FutureBuilder<String>(
        future: _name,
        builder: (context, snapshot) {
          final name = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HighlightCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.ink,
                      child: Text(
                        name == null || name.isEmpty
                            ? '?'
                            : name[0].toUpperCase(),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name ?? (snapshot.hasError ? '—' : '…'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.onInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.auth.currentEmail ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.onInk.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Cambiar nombre'),
                      subtitle: const Text('Es el que ven los demás'),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: name != null,
                      onTap: name == null ? null : () => _changeName(name),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Cambiar contraseña'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePassword,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      ),
    );
  }
}
