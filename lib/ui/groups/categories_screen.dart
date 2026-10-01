import 'package:flutter/material.dart';

import '../../data/app_exception.dart';
import '../../data/group_data_repository.dart';
import '../../domain/models/category.dart';
import '../category_icon.dart';
import '../dialogs.dart';

/// Alta, renombre y baja de las categorías de un grupo.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    required this.groupId,
    required this.repository,
  });

  final String groupId;
  final GroupDataRepository repository;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _categories = _load();

  Future<List<Category>> _load() async =>
      (await widget.repository.load(widget.groupId)).categories;

  void _reload() {
    final future = _load();
    setState(() {
      _categories = future;
    });
  }

  Future<void> _add() async {
    final name = await showTextPrompt(
      context,
      title: 'Nueva categoría',
      label: 'Nombre',
      hint: 'Ej: Mascotas',
      action: 'Agregar',
    );
    if (name == null) return;
    await _run(() => widget.repository.addCategory(widget.groupId, name));
  }

  Future<void> _rename(Category c) async {
    final name = await showTextPrompt(
      context,
      title: 'Renombrar categoría',
      label: 'Nombre',
      action: 'Guardar',
      initialValue: c.name,
    );
    if (name == null || name == c.name) return;
    await _run(() => widget.repository.renameCategory(c.id, name));
  }

  Future<void> _delete(Category c) async {
    final yes = await confirm(
      context,
      title: '¿Borrar "${c.name}"?',
      message: 'Solo se puede borrar si no tiene gastos.',
      action: 'Borrar',
    );
    if (!yes) return;
    await _run(() => widget.repository.deleteCategory(c.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _reload();
    } on AppException catch (e) {
      _show(e.message);
    } catch (_) {
      _show('No se pudo conectar. Revisá tu conexión a internet.');
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Categoría'),
      ),
      body: FutureBuilder<List<Category>>(
        future: _categories,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: _reload,
                child: const Text('Reintentar'),
              ),
            );
          }
          final categories = snapshot.data;
          if (categories == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final c in categories)
                        ListTile(
                          leading: CategoryAvatar(categoryName: c.name),
                          title: Text(c.name),
                          onTap: () => _rename(c),
                          trailing: IconButton(
                            tooltip: 'Borrar ${c.name}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(c),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Tocá una categoría para cambiarle el nombre.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
