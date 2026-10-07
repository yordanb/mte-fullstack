import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';

/// Halaman login: POST /v1/auth/login. Cegah double-submit via _busy.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return; // cegah double-submit
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username dan password wajib diisi')),
      );
      return;
    }
    setState(() => _busy = true);
    final ok = await ref.read(authProvider.notifier).login(_user.text, _pass.text);
    if (mounted) {
      setState(() => _busy = false);
      if (!ok) {
        final err = ref.read(authProvider).error ?? 'Login gagal';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      // Sukses -> redirect GoRouter otomatis via authProvider (tanpa pop manual).
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('MTE Data Center', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  const Text('Masuk dengan akun Anda'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _user,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Masuk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
