import 'package:flutter/material.dart';

import '../application/app_auth.dart';

final class AppAuthGate extends StatefulWidget {
  const AppAuthGate({required this.controller, required this.child, super.key});

  final AppAuthController controller;
  final Widget child;

  @override
  State<AppAuthGate> createState() => _AppAuthGateState();
}

final class _AppAuthGateState extends State<AppAuthGate> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      switch (widget.controller.state) {
        case AppAuthState.loading:
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        case AppAuthState.signedIn:
          return widget.child;
        case AppAuthState.locked:
          return _UnlockScreen(controller: widget.controller);
        case AppAuthState.signedOut:
          return _LoginScreen(controller: widget.controller);
      }
    },
  );
}

final class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) => const Image(
    image: AssetImage('asset/gps_pointer_wordmark.png'),
    width: 110,
    filterQuality: FilterQuality.high,
  );
}

final class _LoginScreen extends StatefulWidget {
  const _LoginScreen({required this.controller});

  final AppAuthController controller;

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

final class _LoginScreenState extends State<_LoginScreen> {
  late final TextEditingController _usernameController;
  final TextEditingController _passwordController = TextEditingController();
  bool _quickUnlock = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.controller.savedUsername ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await widget.controller.login(
      username: _usernameController.text,
      password: _passwordController.text,
      enableQuickUnlock: _quickUnlock,
    );
    if (!mounted || !success) return;
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AuthBrand(),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Accesso',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Usa le credenziali del GPS Pointer Catalog Server.',
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _usernameController,
                          enabled: !widget.controller.busy,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Nome utente',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          enabled: !widget.controller.busy,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _quickUnlock,
                          onChanged: widget.controller.busy
                              ? null
                              : (value) => setState(() => _quickUnlock = value),
                          title: const Text('Accesso rapido'),
                          subtitle: const Text(
                            'Sblocca le sessioni successive con impronta, viso o sblocco dispositivo.',
                          ),
                        ),
                        if (widget.controller.message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.controller.message!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: widget.controller.busy ? null : _submit,
                          icon: widget.controller.busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text('ACCEDI'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'La password non viene memorizzata. Se abiliti Accesso rapido viene conservato soltanto un token revocabile nello storage sicuro Android.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9FB6C2), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _UnlockScreen extends StatelessWidget {
  const _UnlockScreen({required this.controller});

  final AppAuthController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AuthBrand(),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        const Icon(Icons.fingerprint, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          controller.savedDisplayName ??
                              controller.savedUsername ??
                              'Utente GPS Pointer',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sblocca GPS Pointer con la sicurezza del dispositivo.',
                          textAlign: TextAlign.center,
                        ),
                        if (controller.message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            controller.message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: controller.busy
                                ? null
                                : controller.unlock,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('SBLOCCA'),
                          ),
                        ),
                        TextButton(
                          onPressed: controller.busy
                              ? null
                              : controller.usePasswordInstead,
                          child: const Text('Accedi con password'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
