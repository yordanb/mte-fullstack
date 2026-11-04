import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../data/activity_api.dart';
import '../domain/activity_models.dart';
import 'activity_providers.dart';

/// Form tambah/ubah aktivitas + foto multi (progress bar + cegah
/// double-submit). Tambah-foto saat ubah khusus admin, meniru ActForm web.
///
/// Paritas web 4934628: Kategori dropdown tanpa ketik manual (bawaan +
/// kategori dari data + opsi "Replace Gland Packing"), checkbox "DC Dragflow"
/// di samping Tanggal (auto kategori Daily Check Dragflow + crew Pumping,
/// opsi Shift muncul, batal = kategori kembali & shift direset).
class ActivityFormPage extends ConsumerWidget {
  /// null = tambah (date awal dari query), selain itu ubah.
  final String? id;
  final String? initialDate;
  const ActivityFormPage({super.key, this.id, this.initialDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) {
      return _FormBody(key: const ValueKey('new'), initialDate: initialDate);
    }
    final detailAsync = ref.watch(activityDetailProvider(id!));
    return detailAsync.when(
      data: (a) => _FormBody(key: ValueKey('edit-${a.id}'), initial: a),
      loading: () => const AppScaffold(
        title: 'Ubah aktivitas',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Ubah aktivitas',
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(activityDetailProvider(id!)),
        ),
      ),
    );
  }
}

class _FormBody extends ConsumerStatefulWidget {
  final Activity? initial;
  final String? initialDate;
  const _FormBody({super.key, this.initial, this.initialDate});

  @override
  ConsumerState<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends ConsumerState<_FormBody> {
  late String _date;
  late final TextEditingController _title;
  late String _crew;
  late String _cat;
  late final TextEditingController _cn;
  late final TextEditingController _hm;
  late final TextEditingController _desc;
  String _prevCat = '';
  int? _shift;
  final List<XFile> _picked = [];
  bool _busy = false;
  int _pct = 0;
  String? _msg;

  bool get _isEdit => widget.initial != null;
  bool get _isDc => _cat == dcDragflowCategory;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _date = a?.date ?? widget.initialDate ?? toApiDate(DateTime.now());
    _title = TextEditingController(text: a?.title ?? '');
    _crew = (a?.crew ?? '').trim();
    _cat = (a?.category ?? '').trim();
    _cn = TextEditingController(text: a?.cn ?? '');
    _hm = TextEditingController(text: a?.hm != null ? '${a!.hm}' : '');
    _desc = TextEditingController(text: a?.description ?? '');
    _shift = a?.shift;
  }

  @override
  void dispose() {
    _title.dispose();
    _cn.dispose();
    _hm.dispose();
    _desc.dispose();
    super.dispose();
  }

  /// Check "DC Dragflow" (web ActForm): kategori & crew diisi otomatis; opsi
  /// Shift muncul karena kategori DC. Saat dibatalkan: kategori kembali ke
  /// pilihan sebelumnya & shift direset.
  void _toggleDc(bool on) {
    setState(() {
      if (on) {
        if (!_isDc) _prevCat = _cat;
        _cat = dcDragflowCategory;
        _crew = 'Pumping';
      } else {
        _cat = _prevCat;
        _shift = null;
      }
    });
  }

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isNotEmpty) setState(() => _picked.addAll(files));
  }

  Future<void> _pickDate() async {
    final cur = DateTime.tryParse(_date) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = toApiDate(d)); // lokal, bukan UTC
  }

  Future<void> _save() async {
    if (_busy) return; // cegah double-submit
    if (_title.text.trim().isEmpty) {
      setState(() => _msg = 'Judul wajib diisi.');
      return;
    }
    if (_crew.trim().isEmpty) {
      setState(() => _msg = 'Crew wajib diisi.');
      return;
    }
    // Validasi web ActForm untuk Daily Check Dragflow.
    if (_isDc) {
      if (_cn.text.trim().isEmpty) {
        setState(() => _msg = 'Unit / CN wajib dipilih untuk Daily Check Dragflow.');
        return;
      }
      if (_hm.text.trim().isEmpty) {
        setState(() => _msg = 'Hourmeter wajib diisi untuk Daily Check Dragflow.');
        return;
      }
      if (_shift == null) {
        setState(() => _msg = 'Shift wajib dipilih untuk Daily Check Dragflow.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _pct = 0;
      _msg = null;
    });
    void prog(int sent, int total) {
      if (total > 0 && mounted) {
        setState(() => _pct = (sent / total * 100).round());
      }
    }

    try {
      final api = ref.read(activityApiProvider);
      if (_isEdit) {
        await api.patch(widget.initial!.id, {
          'date': _date,
          'title': _title.text.trim(),
          'category': _cat.isEmpty ? null : _cat,
          'crew': _crew.trim(),
          'cn': _cn.text.trim().isEmpty ? null : _cn.text.trim().toUpperCase(),
          'hm': _hm.text.trim().isEmpty ? null : _hm.text.trim(),
          'shift': _shift != null ? '$_shift' : null,
          'description': _desc.text.isEmpty ? null : _desc.text,
        });
        if (_picked.isNotEmpty) {
          await api.addPhotos(widget.initial!.id, _picked.map((e) => e.path).toList(),
              onProgress: prog);
        }
        ref.invalidate(activityDetailProvider(widget.initial!.id));
      } else {
        await api.create(
          date: _date,
          title: _title.text.trim(),
          crew: _crew.trim(),
          category: _cat.isEmpty ? null : _cat,
          cn: _cn.text.trim().isEmpty ? null : _cn.text.trim(),
          hm: _hm.text.trim().isEmpty ? null : _hm.text.trim(),
          shift: _shift,
          description: _desc.text.isEmpty ? null : _desc.text,
          filePaths: _picked.map((e) => e.path).toList(),
          onProgress: prog,
        );
      }
      invalidateActivityLists(ref);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _msg = e.toString();
          _busy = false;
        });
      }
    }
  }

  /// Unit / CN khusus DC Dragflow: hanya pasangan EX-WP web; nilai lama
  /// (di luar daftar) tetap tampil sebagai "(data lama)".
  Widget _dcCnField() {
    final cur = _cn.text.trim().toUpperCase();
    final known = dragflowPairs.any((p) => p.$2 == cur);
    return DropdownButtonFormField<String>(
      value: cur.isEmpty ? null : cur,
      decoration: const InputDecoration(
        labelText: 'Unit / CN',
        border: OutlineInputBorder(),
      ),
      hint: const Text('— pilih unit —'),
      items: [
        for (final p in dragflowPairs)
          DropdownMenuItem(value: p.$2, child: Text('${p.$1} - ${p.$2}')),
        if (cur.isNotEmpty && !known)
          DropdownMenuItem(value: cur, child: Text('$cur (data lama)')),
      ],
      onChanged: _busy ? null : (v) => setState(() => _cn.text = v ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).isAdmin;
    final showAddPhotos = !_isEdit || isAdmin;
    final filtersAsync = ref.watch(activityFiltersProvider);
    final dataCats = switch (filtersAsync) {
      AsyncData(:final value) => value.categories,
      _ => const <String>[],
    };
    final crews = crewChoices(_crew);
    final cats = catChoices(fromData: dataCats, current: _cat);

    return AppScaffold(
      title: _isEdit ? 'Ubah aktivitas' : 'Tambah aktivitas',
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal'),
                  subtitle: Text(fmtDate(_date)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _busy ? null : _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Tandai aktivitas Daily Check Dragflow: Kategori otomatis '
                    'terisi, Crew jadi Pumping, dan pilihan Shift muncul.',
                child: FilterChip(
                  label: const Text('DC Dragflow'),
                  selected: _isDc,
                  onSelected: _busy ? null : _toggleDc,
                ),
              ),
            ],
          ),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Judul',
              hintText: 'cth Perbaikan pompa WP855',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_isDc) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _crew.isEmpty ? null : _crew,
                    decoration: const InputDecoration(
                      labelText: 'Crew (wajib)',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('— pilih crew —'),
                    items: [
                      for (final c in crews) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _crew = v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: dcDragflowCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: dcDragflowCategory, child: Text(dcDragflowCategory)),
                    ],
                    onChanged: null, // terkunci selama DC Dragflow
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Shift'),
                const SizedBox(width: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Shift 1')),
                    ButtonSegment(value: 2, label: Text('Shift 2')),
                  ],
                  selected: _shift != null ? {_shift!} : <int>{},
                  onSelectionChanged:
                      _busy ? null : (s) => setState(() => _shift = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _crew.isEmpty ? null : _crew,
                    decoration: const InputDecoration(
                      labelText: 'Crew (wajib)',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('— pilih crew —'),
                    items: [
                      for (final c in crews) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _crew = v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _cat.isEmpty ? null : _cat,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('— pilih kategori —'),
                    items: [
                      for (final c in cats) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v == null) return;
                            if (v == dcDragflowCategory) {
                              _toggleDc(true);
                            } else {
                              setState(() => _cat = v);
                            }
                          },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _isDc
                    ? _dcCnField()
                    : TextField(
                        controller: _cn,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (v) {
                          final u = v.toUpperCase();
                          if (u != v) {
                            _cn.value = TextEditingValue(
                              text: u,
                              selection: TextSelection.collapsed(offset: u.length),
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Unit / CN',
                          hintText: 'cth WP855',
                          border: OutlineInputBorder(),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _hm,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Hourmeter',
                    hintText: 'cth 12500',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Keterangan',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (showAddPhotos) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.photo_library),
              label: Text(_isEdit
                  ? 'Tambah foto (admin, boleh banyak)'
                  : 'Foto (boleh banyak)${_picked.isEmpty ? '' : ' (${_picked.length})'}'),
            ),
            if (_picked.isNotEmpty)
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _picked.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (c, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_picked[i].path),
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _busy
                              ? null
                              : () => setState(() => _picked.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 8),
            Text(_msg!, style: const TextStyle(color: Colors.red)),
          ],
          if (_busy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _pct > 0 ? _pct / 100 : null),
            const SizedBox(height: 4),
            Text('Mengunggah... $_pct% — jangan tutup halaman.'),
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
      ),
    );
  }
}
