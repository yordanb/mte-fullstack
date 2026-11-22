import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/token_storage.dart';

/// Halaman login: POST /v1/auth/login.
/// Mendukung opsi login sidik jari (biometrik) bila perangkat mendukung.
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
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  bool _rememberBio = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final bio = ref.read(biometricServiceProvider);
    final storage = ref.read(tokenStorageProvider);
    final available = await bio.isSupported();
    final enabled = await storage.isBioEnabled();
    if (mounted) {
      setState(() {
        _bioAvailable = available;
        _bioEnabled = enabled;
        _rememberBio = enabled;
      });
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username dan password wajib diisi')),
      );
      return;
    }
    setState(() => _busy = true);
    final ok = await ref.read(authProvider.notifier).login(
          _user.text.trim(),
          _pass.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      final err = ref.read(authProvider).error ?? 'Login gagal';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    // Sukses -> simpan/hapus kredensial biometrik sesuai checkbox
    final storage = ref.read(tokenStorageProvider);
    if (_bioAvailable) {
      if (_rememberBio) {
        await storage.saveBioCreds(_user.text.trim(), _pass.text);
      } else {
        await storage.clearBioCreds();
      }
    }
    // Redirect otomatis via GoRouter (auth state berubah)
  }

  Future<void> _loginWithBiometric() async {
    if (_busy) return;
    final bio = ref.read(biometricServiceProvider);
    final storage = ref.read(tokenStorageProvider);
    final cred = await storage.readBiometricCredential();
    if (!mounted) return;
    if (cred == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login sidik jari belum diaktifkan')),
      );
      return;
    }
    setState(() => _busy = true);
    final ok = await bio.authenticate();
    if (!ok) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final success = await ref.read(authProvider.notifier).login(cred.$1, cred.$2);
    if (mounted) {
      setState(() => _busy = false);
      if (!success) {
        final err = ref.read(authProvider).error ?? 'Login sidik jari gagal';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
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
                  Text('MTE Data Center',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  const Text('Masuk dengan akun Anda'),
                  const SizedBox(height: 24),
                  // Tombol login sidik jari (muncul bila sudah diaktifkan)
                  if (_bioEnabled) ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _loginWithBiometric,
                      icon: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: const Text('Masuk dengan Sidik Jari'),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _user,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Username', border: OutlineInputBorder()),
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
                        icon: Icon(_obscure
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_bioAvailable) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _rememberBio,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _rememberBio = v ?? false),
                      title: const Text('Aktifkan login sidik jari'),
                      subtitle: const Text(
                          'Masuk hanya dengan verifikasi sidik jari'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Masuk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

extension _Creds on TokenStorage {
  Future<(String username, String password)?> readBiometricCredential() async {
    final u = await readBioUser();
    final p = await readBioPass();
    if (u == null || p == null) return null;
    return (u, p);
  }
}