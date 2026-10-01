import 'package:flutter/material.dart';

/// Pide un texto en un diálogo. Devuelve el texto sin espacios de los
/// costados, o `null` si se canceló.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String hint = '',
  String initialValue = '',
  bool uppercase = false,
  bool obscure = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    label: label,
    hint: hint,
    action: action,
    initialValue: initialValue,
    uppercase: uppercase,
    obscure: obscure,
  ),
);

/// Pregunta antes de una acción. Devuelve `true` solo si se confirmó.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result == true;
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
    required this.initialValue,
    required this.uppercase,
    required this.obscure,
  });

  final String title;
  final String label;
  final String hint;
  final String action;
  final String initialValue;
  final bool uppercase;
  final bool obscure;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

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
        obscureText: widget.obscure,
        textCapitalization: widget.uppercase
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint.isEmpty ? null : widget.hint,
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
