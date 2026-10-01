import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_exception.dart';
import '../../data/auth_repository.dart';
import '../theme.dart';
import 'reset_password_screen.dart';

/// Ingreso y registro con email y contraseña.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      if (_registering) {
        final signedIn = await widget.auth.signUp(
          email: email,
          password: _password.text,
          name: _name.text.trim(),
        );
        if (!signedIn) {
          _error = 'Te mandamos un email para confirmar la cuenta.';
        }
      } else {
        await widget.auth.signIn(email: email, password: _password.text);
      }
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudo conectar. Revisá tu conexión a internet.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() {
    setState(() => _error = null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResetPasswordScreen(
          auth: widget.auth,
          initialEmail: _email.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    // Pantalla de bienvenida en el azul del logo (el mismo del splash, así
    // la transición no tiene cortes). Sobre el azul, el botón principal va en
    // verde agua y los textos en blanco.
    final theme = base.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          backgroundColor: const WidgetStatePropertyAll(AppColors.accent),
          foregroundColor: const WidgetStatePropertyAll(AppColors.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(AppColors.onInk),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        errorStyle: const TextStyle(
          color: AppColors.coral,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: theme,
        child: Scaffold(
          backgroundColor: AppColors.ink,
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
                        Image.asset(
                          'assets/branding/logo_full.png',
                          height: 170,
                          semanticLabel: 'mitimiti',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _registering
                              ? 'Creá tu cuenta'
                              : 'Ingresá a tu cuenta',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.onInk,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_registering) ...[
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                            ),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresá tu nombre'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: (v) =>
                              (v == null || !v.trim().contains('@'))
                              ? 'Ingresá un email válido'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: [
                            _registering
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          onFieldSubmitted: (_) => _busy ? null : _submit(),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Mínimo 6 caracteres'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.coral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _registering ? 'Crear cuenta' : 'Ingresar',
                                ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _registering = !_registering;
                                  _error = null;
                                }),
                          child: Text(
                            _registering
                                ? '¿Ya tenés cuenta? Ingresá'
                                : '¿No tenés cuenta? Registrate',
                          ),
                        ),
                        if (!_registering)
                          TextButton(
                            onPressed: _busy ? null : _forgotPassword,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
