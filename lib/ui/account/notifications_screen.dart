import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/profile_repository.dart';
import '../../domain/models/notification_prefs.dart';

/// Qué notificaciones push recibir. Cada cambio se guarda al toque.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.profile});

  final ProfileRepository profile;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationPrefs? _prefs;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final prefs = await widget.profile.myNotificationPrefs();
      if (mounted) setState(() => _prefs = prefs);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Muestra el cambio enseguida y lo deshace si no se pudo guardar.
  Future<void> _save(NotificationPrefs updated) async {
    final previous = _prefs;
    setState(() => _prefs = updated);
    try {
      await widget.profile.updateNotificationPrefs(updated);
    } on AppException catch (e) {
      _revert(previous, e.message);
    } catch (_) {
      _revert(previous, 'No se pudo conectar. Revisá tu conexión a internet.');
    }
  }

  void _revert(NotificationPrefs? previous, String message) {
    if (!mounted) return;
    setState(() => _prefs = previous);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: prefs == null
          ? Center(
              child: _loadFailed
                  ? OutlinedButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    )
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.receipt_long_outlined),
                        title: const Text('Gastos nuevos'),
                        subtitle: const Text('Cuando otro carga un gasto'),
                        value: prefs.expenseNew,
                        onChanged: (v) => _save(prefs.copyWith(expenseNew: v)),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.edit_outlined),
                        title: const Text('Gastos editados o borrados'),
                        subtitle: const Text('Cuando otro cambia un gasto'),
                        value: prefs.expenseChanged,
                        onChanged: (v) =>
                            _save(prefs.copyWith(expenseChanged: v)),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.payments_outlined),
                        title: const Text('Pagos'),
                        subtitle: const Text(
                          'Cuando registran un pago tuyo o para vos',
                        ),
                        value: prefs.settlement,
                        onChanged: (v) => _save(prefs.copyWith(settlement: v)),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.person_add_alt_outlined),
                        title: const Text('Miembros nuevos'),
                        subtitle: const Text('Cuando alguien se une al grupo'),
                        value: prefs.memberJoined,
                        onChanged: (v) =>
                            _save(prefs.copyWith(memberJoined: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Si no te llegan, revisá que Mitimiti tenga permitidas '
                    'las notificaciones en los ajustes del teléfono.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}
