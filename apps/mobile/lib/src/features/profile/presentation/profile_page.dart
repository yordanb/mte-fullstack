import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/auth/token_storage.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';

import '../data/profile_api.dart';

/// Profil: avatar (?token=, inisial bila 404) + ganti foto + ganti
/// password. Meniru ProfileModal web.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  bool _busyPw = false;
  bool _busyAv = false;
  String? _msg;
  int _avatarBust = 0;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  String _initials(String username) {
    final u = username.trim();
    if (u.isEmpty) return '?';
    if (u.length == 1) return u.toUpperCase();
    return u.substring(0, 2).toUpperCase();
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() {
      _busyAv = true;
      _msg = null;
    });
    try {
      await ref.read(profileApiProvider).uploadAvatar(x.path);
      await ref.read(authProvider.notifier).refreshMe();
      if (mounted) {
        setState(() {
          _msg = 'Foto profil diperbarui.';
          _avatarBust = DateTime.now().millisecondsSinceEpoch;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _msg = 'gagal: ${apiMessage(e)}');
    } finally {
      if (mounted) setState(() => _busyAv = false);
    }
  }

  Future<void> _savePw() async {
    if (_busyPw) return;
    if (_new.text.length < 4) {
      setState(() => _msg = 'Password baru min 4 karakter.');
      return;
    }
    setState(() {
      _busyPw = true;
      _msg = null;
    });
    try {
      await ref.read(profileApiProvider).changePassword(
            oldPassword: _old.text,
            newPassword: _new.text,
          );
      _old.clear();
      _new.clear();
      if (mounted) setState(() => _msg = 'Password berhasil diganti.');
    } catch (e) {
      if (mounted) setState(() => _msg = 'gagal: ${apiMessage(e)}');
    } finally {
      if (mounted) setState(() => _busyPw = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final tokenAsync = ref.watch(accessTokenProvider);
    final token = switch (tokenAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };

    return AppScaffold(
      title: 'Profil',
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                child: (token == null || auth.username.isEmpty)
                    ? Text(_initials(auth.username))
                    : ClipOval(
                        child: Image.network(
                          '${ProfileApi.avatarUrl(auth.username, token)}&t=$_avatarBust',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Text(_initials(auth.username)),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.username,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(auth.role,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _busyAv ? null : _pickAvatar,
                child: Text(_busyAv ? '...' : 'Ganti foto'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _old,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password lama',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _new,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password baru (min 4)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 8),
            Text(_msg!),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busyPw ? null : _savePw,
              child: Text(_busyPw ? 'Menyimpan...' : 'Ganti password'),
            ),
          ),
        ],
      ),
    );
  }
}
