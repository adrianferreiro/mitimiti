import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_exception.dart';
import '../../data/auth_repository.dart';
import '../theme.dart';

/// "Olvidé mi contraseña": pide el email, manda un código y con ese código
/// guarda una contraseña nueva. Al terminar la app entra directo.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.auth,
    this.initialEmail = '',
  });

  final AuthRepository auth;
  final String initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _repeated = TextEditingController();

  /// Ya se mandó el código: se muestra el paso de código y contraseña nueva.
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    widget.auth.endRecovery();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _repeated.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_codeSent && !_formKey.currentState!.validate()) return;
    final sent = await _run(
      () => widget.auth.sendRecoveryCode(_email.text.trim()),
    );
    if (!sent || !mounted) return;
    setState(() => _codeSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Te mandamos un código a ${_email.text.trim()}.')),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _run(
      () => widget.auth.resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
      ),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Al cerrar esta pantalla, endRecovery hace que la app pase a los grupos.
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada.')),
    );
  }

  /// Corre [action] mostrando el progreso y el error. Devuelve si salió bien.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudo conectar. Revisá tu conexión a internet.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _codeSent
                          ? 'Ingresá el código que te mandamos a '
                                '${_email.text.trim()} y elegí una contraseña '
                                'nueva. Si no lo ves, revisá en spam.'
                          : 'Te vamos a mandar un código por email para '
                                'que elijas una contraseña nueva.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (!_codeSent)
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofocus: widget.initialEmail.isEmpty,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _busy ? null : _sendCode(),
                        validator: (v) => (v == null || !v.trim().contains('@'))
                            ? 'Ingresá un email válido'
                            : null,
                      )
                    else ...[
                      TextFormField(
                        controller: _code,
                        decoration: const InputDecoration(labelText: 'Código'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        validator: (v) => (v == null || v.trim().length < 6)
                            ? 'Ingresá el código del email'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña nueva',
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _repeated,
                        decoration: const InputDecoration(
                          labelText: 'Repetí la contraseña',
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            _busy ? null : _resetPassword(),
                        validator: (v) => v != _password.text
                            ? 'Las contraseñas no coinciden'
                            : null,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : (_codeSent ? _resetPassword : _sendCode),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _codeSent
                                  ? 'Cambiar contraseña'
                                  : 'Enviar código',
                            ),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : _sendCode,
                        child: const Text('Reenviar código'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                // Descarta un código ya validado del email
                                // anterior.
                                widget.auth.endRecovery();
                                setState(() {
                                  _codeSent = false;
                                  _error = null;
                                  _code.clear();
                                });
                              },
                        child: const Text('Usar otro email'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
