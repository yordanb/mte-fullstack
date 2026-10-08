import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';

import '../data/import_api.dart';
import '../domain/import_models.dart';

/// Update Data: tile Report Oli (Dry-run + Commit) dan DBR (Upload),
/// polling progres 2 detik. Meniru ImportPage web. Upload butuh
/// `import.add`; halaman butuh `import.view`.
class UpdateDataPage extends ConsumerWidget {
  const UpdateDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.can('import', 'view')) {
      return const AppScaffold(
        title: 'Update Data',
        body: Center(
            child: Text('Role Anda tidak memiliki akses ke menu ini.')),
      );
    }
    final canUpload = auth.can('import', 'add');
    return AppScaffold(
      title: 'Update Data',
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Unggah file Excel untuk memperbarui data operasional'),
          const SizedBox(height: 8),
          _OilTile(canUpload: canUpload),
          const SizedBox(height: 12),
          _DbrTile(canUpload: canUpload),
        ],
      ),
    );
  }
}

class _OilTile extends ConsumerStatefulWidget {
  final bool canUpload;
  const _OilTile({required this.canUpload});

  @override
  ConsumerState<_OilTile> createState() => _OilTileState();
}

class _OilTileState extends ConsumerState<_OilTile> {
  String? _fname;
  String? _path;
  bool _busy = false;
  int _upPct = 0;
  String? _msg;
  DryRunResult? _dry;
  ImportProgress? _prog;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (r != null && r.files.single.path != null) {
      setState(() {
        _fname = r.files.single.name;
        _path = r.files.single.path;
        _dry = null;
        _prog = null;
        _msg = null;
      });
    }
  }

  void _upProg(int sent, int total) {
    if (total > 0 && mounted) {
      setState(() => _upPct = (sent / total * 100).round());
    }
  }

  Future<void> _send(bool dry) async {
    if (_busy || _path == null) return;
    setState(() {
      _busy = true;
      _upPct = 0;
      _msg = 'mengunggah...';
      _prog = null;
      if (dry) _dry = null;
    });
    try {
      final api = ref.read(importApiProvider);
      if (dry) {
        final r = await api.dryRun(_path!, onProgress: _upProg);
        if (mounted) {
          setState(() {
            _dry = r;
            _msg = 'Dry-run: ok=${r.ok} fail=${r.fail}';
          });
        }
      } else {
        final id = await api.commitOil(_path!, onProgress: _upProg);
        if (mounted) setState(() => _msg = 'Commit diterima, mulai membaca file...');
        _poll(id);
        return;
      }
    } catch (e) {
      if (mounted) setState(() => _msg = 'gagal: ${apiMessage(e)}');
    } finally {
      if (mounted && dry) setState(() => _busy = false);
    }
  }

  void _poll(String id) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final s = await ref.read(importApiProvider).status(id);
        if (!mounted) return;
        setState(() => _prog = s);
        if (s.status == 'COMMITTED') {
          t.cancel();
          setState(() {
            _busy = false;
            _msg = 'Selesai: ok=${s.okRows} fail=${s.failRows}';
          });
        } else if (s.status == 'FAILED') {
          t.cancel();
          setState(() {
            _busy = false;
            _msg = 'Gagal di server, cek log api.';
          });
        }
      } catch (e) {
        t.cancel();
        if (mounted) {
          setState(() {
            _busy = false;
            _msg = 'gagal pantau: ${apiMessage(e)}';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_prog != null && _prog!.totalRows > 0)
        ? (_prog!.processedRows / _prog!.totalRows * 100).round()
        : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Report Analisa Oli',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('Data lab 116 kolom per vessel + unit'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _pick,
              child: Text(_fname == null ? 'Pilih file .xlsx' : 'File: $_fname'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_busy || _path == null || !widget.canUpload)
                        ? null
                        : () => _send(true),
                    child: const Text('Dry-run'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: (_busy || _path == null || !widget.canUpload)
                        ? null
                        : () => _send(false),
                    child: _busy
                        ? const Text('Mengunggah...')
                        : const Text('Commit'),
                  ),
                ),
              ],
            ),
            if (_busy && _upPct > 0 && _prog == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Mengunggah file... $_upPct%'),
              ),
            if (_prog != null) ...[
              const SizedBox(height: 8),
              if (_prog!.totalRows == 0)
                Text('Membaca & validasi file... ${_prog!.processedRows} baris terbaca')
              else ...[
                LinearProgressIndicator(value: pct / 100),
                const SizedBox(height: 4),
                Text('Menyimpan ${_prog!.processedRows}/${_prog!.totalRows} ($pct%)'),
              ],
            ],
            if (_dry != null) ...[
              const SizedBox(height: 8),
              Text('Dry-run: ok=${_dry!.ok} fail=${_dry!.fail} dari ${_dry!.total}'),
              if (_dry!.errors.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('Error (maks 50):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final e in _dry!.errors.take(10))
                  Text('baris ${e.row}: ${e.error}'),
                if (_dry!.errors.length > 10)
                  Text('... +${_dry!.errors.length - 10} lainnya'),
              ],
              if (_dry!.preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('Preview:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final p in _dry!.preview.take(3))
                  Text('${p.labNo} • ${p.vesselId}/${p.unitId} • ${p.condition}'),
              ],
            ],
            if (_msg != null) ...[
              const SizedBox(height: 8),
              Text(_msg!),
            ],
          ],
        ),
      ),
    );
  }
}

class _DbrTile extends ConsumerStatefulWidget {
  final bool canUpload;
  const _DbrTile({required this.canUpload});

  @override
  ConsumerState<_DbrTile> createState() => _DbrTileState();
}

class _DbrTileState extends ConsumerState<_DbrTile> {
  String? _fname;
  String? _path;
  bool _busy = false;
  int _upPct = 0;
  String? _msg;
  ImportProgress? _prog;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (r != null && r.files.single.path != null) {
      setState(() {
        _fname = r.files.single.name;
        _path = r.files.single.path;
        _prog = null;
        _msg = null;
      });
    }
  }

  Future<void> _up() async {
    if (_busy || _path == null) return;
    setState(() {
      _busy = true;
      _upPct = 0;
      _msg = 'mengunggah...';
      _prog = null;
    });
    try {
      final id = await ref.read(importApiProvider).uploadDbr(
        _path!,
        onProgress: (s, t) {
          if (t > 0 && mounted) setState(() => _upPct = (s / t * 100).round());
        },
      );
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 2), (t) async {
        try {
          final s = await ref.read(importApiProvider).status(id);
          if (!mounted) return;
          setState(() => _prog = s);
          if (s.status == 'COMMITTED') {
            t.cancel();
            setState(() {
              _busy = false;
              _msg = 'Selesai: ok=${s.okRows} fail=${s.failRows}';
            });
          } else if (s.status == 'FAILED') {
            t.cancel();
            setState(() {
              _busy = false;
              _msg = 'Gagal di server.';
            });
          }
        } catch (e) {
          t.cancel();
          if (mounted) {
            setState(() {
              _busy = false;
              _msg = 'gagal: ${apiMessage(e)}';
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _msg = 'gagal: ${apiMessage(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_prog != null && _prog!.totalRows > 0)
        ? (_prog!.processedRows / _prog!.totalRows * 100).round()
        : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('DBR Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('Daily breakdown per code number'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _pick,
              child: Text(_fname == null ? 'Pilih file .xlsx' : 'File: $_fname'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_busy || _path == null || !widget.canUpload)
                  ? null
                  : _up,
              child: _busy ? const Text('Mengunggah...') : const Text('Upload DBR'),
            ),
            if (_busy && _upPct > 0 && _prog == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Mengunggah file... $_upPct%'),
              ),
            if (_prog != null) ...[
              const SizedBox(height: 8),
              if (_prog!.totalRows > 0) ...[
                LinearProgressIndicator(value: pct / 100),
                const SizedBox(height: 4),
                Text('${_prog!.processedRows}/${_prog!.totalRows} ($pct%)'),
              ] else
                Text('Membaca file... ${_prog!.processedRows} baris terbaca'),
            ],
            if (_msg != null) ...[
              const SizedBox(height: 8),
              Text(_msg!),
            ],
          ],
        ),
      ),
    );
  }
}
