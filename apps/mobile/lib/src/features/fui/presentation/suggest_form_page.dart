import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';

import '../data/fui_api.dart';
import 'fui_providers.dart';

/// Form Suggest Follow Up (SuggestModal web jadi halaman):
/// saran + PIC, riwayat banyak per lab. Cegah double-submit.
class SuggestFormPage extends ConsumerStatefulWidget {
  final String labNo;
  final String vesselId;
  final String unitId;
  final String condition;
  const SuggestFormPage({
    super.key,
    required this.labNo,
    required this.vesselId,
    required this.unitId,
    required this.condition,
  });

  @override
  ConsumerState<SuggestFormPage> createState() => _SuggestFormPageState();
}

class _SuggestFormPageState extends ConsumerState<SuggestFormPage> {
  late final TextEditingController _text;
  late final TextEditingController _pic;
  bool _busy = false;
  bool _done = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
    _pic = TextEditingController();
  }

  @override
  void dispose() {
    _text.dispose();
    _pic.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_text.text.trim().isEmpty) {
      setState(() => _msg = 'Isi saran wajib diisi.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await ref.read(fuiApiProvider).addSuggest(
            labNo: widget.labNo,
            suggestion: _text.text.trim(),
            pic: _pic.text.trim().isEmpty ? null : _pic.text.trim(),
          );
      invalidateFuiLists(ref);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _msg = e.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Suggest Follow Up',
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('${widget.vesselId} / ${widget.unitId} • Lab ${widget.labNo} • ${widget.condition}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (_done) ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Tersimpan. Klik lagi untuk menambah riwayat lain.'),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Tutup'),
              ),
            ),
          ] else ...[
            TextField(
              controller: _text,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Saran / rekomendasi',
                hintText: 'cth Ganti oli + filter, monitor 250 HM',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pic,
              decoration: const InputDecoration(
                labelText: 'PIC',
                hintText: 'nama penanggung jawab',
                border: OutlineInputBorder(),
              ),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 8),
              Text(_msg!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Menyimpan...' : 'Simpan'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
