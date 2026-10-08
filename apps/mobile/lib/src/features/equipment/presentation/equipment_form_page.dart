import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../data/equipment_api.dart';
import '../domain/equipment_models.dart';
import 'equipment_providers.dart';

const _cats = ['BIGWHEEL', 'LIGHTING', 'MOBILE', 'PUMPING'];

/// Field teks form (EQ_EDIT_FIELDS web Pages.tsx:344-351).
const _editFields = [
  ('unit_model', 'Model'),
  ('unit_type', 'Unit Type'),
  ('unit_product', 'Product'),
  ('cn_serial_no', 'Serial No'),
  ('cn_lokasi', 'CN Lokasi'),
  ('status', 'Status'),
  ('operasional', 'Operasional'),
  ('pump_group', 'Pump Group'),
  ('lokasi', 'Lokasi'),
  ('remark', 'Remark'),
  ('offhire', 'Offhire'),
];

/// Form tambah/ubah unit (EqForm web). Tambah: CN + kategori wajib.
/// Cegah double-submit via _busy.
class EquipmentFormPage extends ConsumerWidget {
  final String? cn; // null = tambah
  const EquipmentFormPage({super.key, this.cn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cn == null) return const _FormBody();
    final detailAsync = ref.watch(eqDetailProvider(cn!.toUpperCase()));
    return detailAsync.when(
      data: (e) => _FormBody(key: ValueKey('edit-${e.cn}'), initial: e),
      loading: () => const AppScaffold(
        title: 'Ubah unit',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Ubah unit',
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(eqDetailProvider(cn!.toUpperCase())),
        ),
      ),
    );
  }
}

class _FormBody extends ConsumerStatefulWidget {
  final Equipment? initial;
  const _FormBody({super.key, this.initial});

  @override
  ConsumerState<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends ConsumerState<_FormBody> {
  late final TextEditingController _cn;
  late String _cat;
  late final Map<String, TextEditingController> _ctls;
  late bool _aktif;
  bool _busy = false;
  String? _msg;

  bool get _isEdit => widget.initial != null;

  String? _val(Equipment? e, String key) => switch (key) {
        'unit_model' => e?.unitModel,
        'unit_type' => e?.unitType,
        'unit_product' => e?.unitProduct,
        'cn_serial_no' => e?.cnSerialNo,
        'cn_lokasi' => e?.cnLokasi,
        'status' => e?.status,
        'operasional' => e?.operasional,
        'pump_group' => e?.pumpGroup,
        'lokasi' => e?.lokasi,
        'remark' => e?.remark,
        'offhire' => e?.offhire,
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _cn = TextEditingController(text: e?.cn ?? '');
    _cat = e?.category ?? 'LIGHTING';
    _ctls = {for (final f in _editFields) f.$1: TextEditingController(text: _val(e, f.$1) ?? '')};
    _aktif = e?.aktif ?? true;
  }

  @override
  void dispose() {
    _cn.dispose();
    for (final c in _ctls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final cn = _cn.text.trim().toUpperCase();
    if (!_isEdit && cn.isEmpty) {
      setState(() => _msg = 'CN wajib diisi.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final api = ref.read(equipmentApiProvider);
      final body = {
        if (!_isEdit) 'cn': cn,
        if (!_isEdit) 'category': _cat,
        for (final f in _editFields) f.$1: _ctls[f.$1]!.text,
        'aktif': _aktif,
      };
      if (_isEdit) {
        await api.patch(widget.initial!.cn, body);
        ref.invalidate(eqDetailProvider(widget.initial!.cn));
      } else {
        await api.create(body);
      }
      invalidateEqLists(ref);
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Ubah ${widget.initial!.cn}' : 'Tambah Unit',
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (!_isEdit) ...[
            TextField(
              controller: _cn,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'CN (cth TL960)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _cat,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in _cats) DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _cat = v ?? 'LIGHTING'),
            ),
            const SizedBox(height: 12),
          ],
          for (final f in _editFields) ...[
            TextField(
              controller: _ctls[f.$1],
              decoration: InputDecoration(
                labelText: f.$2,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktif'),
            value: _aktif,
            onChanged: (v) => setState(() => _aktif = v ?? true),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 4),
            Text(_msg!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 8),
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
