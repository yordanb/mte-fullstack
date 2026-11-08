import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../data/manpower_api.dart';
import '../domain/manpower_models.dart';
import 'manpower_providers.dart';
import 'manpower_widgets.dart';

/// Manpower (pengelompokan Section/Crew/Status) — paritas web ManpowerGroup.tsx.
/// Master data = manpower_profile; sumber metrik = manpower_month.
class ManpowerGroupPage extends ConsumerStatefulWidget {
  const ManpowerGroupPage({super.key});

  @override
  ConsumerState<ManpowerGroupPage> createState() => _ManpowerGroupPageState();
}

class _ManpowerGroupPageState extends ConsumerState<ManpowerGroupPage> {
  final _search = TextEditingController();
  bool _autoFillTried = false;
  String _msg = '';
  final Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setMsg(String m) => setState(() => _msg = m);

  Future<void> _runAutofill({bool silentBoot = false}) async {
    try {
      final r = await ref.read(manpowerApiProvider).autofill();
      final created = (r['created'] as num?)?.toInt() ?? 0;
      final filled = (r['filled'] as num?)?.toInt() ?? 0;
      final skipped = (r['skipped'] as num?)?.toInt() ?? 0;
      _setMsg(silentBoot
          ? 'Pengelompokan awal dibuat otomatis dari jabatan. Silakan koreksi bila perlu.'
          : 'Isi otomatis: ${mpNum(created)} profil baru, ${mpNum(filled)} dilengkapi'
              '${skipped > 0 ? ', ${mpNum(skipped)} tanpa tebakan (isi manual)' : ''}.');
      ref.read(manpowerManageTickProvider.notifier).bump();
    } catch (e) {
      _setMsg('isi otomatis gagal: ${apiMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(manpowerManageProvider);
    final auth = ref.watch(authProvider);
    final canEdit = auth.can('manpower', 'edit');

    // Set periode default setelah data pertama.
    ref.listen(manpowerManageProvider, (_, next) {
      next.whenData((d) {
        final f = ref.read(manpowerManageFilterProvider);
        if (f.periode.isEmpty && (d.periode ?? '').isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ref.read(manpowerManageFilterProvider).periode.isEmpty) {
              ref.read(manpowerManageFilterProvider.notifier).setPeriode(d.periode!);
            }
          });
        }
        // Isi otomatis sekali bila belum ada yang dikelompokkan.
        if (canEdit &&
            !_autoFillTried &&
            d.manpower > 0 &&
            d.classified == 0 &&
            d.data.isEmpty) {
          _autoFillTried = true;
          _runAutofill(silentBoot: true);
        }
      });
    });

    return AppScaffold(
      title: 'Manpower',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(manpowerManageTickProvider.notifier).bump();
          await ref.read(manpowerManageProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _filters(async, canEdit),
            if (_msg.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_msg,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF1D4ED8))),
              ),
            ],
            const SizedBox(height: 12),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                  message: '$e',
                  onRetry: () =>
                      ref.read(manpowerManageTickProvider.notifier).bump()),
              data: (d) {
                if (d.periode == null || d.manpower == 0) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Belum ada data manpower untuk periode ini. Upload file '
                        'RptInnovatorMonthly di halaman Update Data (menu Operasional).',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return _body(d, canEdit);
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _filters(AsyncValue<ManpowerManage> async, bool canEdit) {
    final f = ref.watch(manpowerManageFilterProvider);
    final d = async.maybeWhen(data: (v) => v, orElse: () => null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                    labelText: 'Cari', hintText: 'Nama / NRP / jabatan',
                    isDense: true),
                onSubmitted: (v) {
                  ref
                      .read(manpowerManageFilterProvider.notifier)
                      .setSearch(v.trim());
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: f.pageSize,
              items: [
                for (final n in [25, 50, 100])
                  DropdownMenuItem(
                      value: n,
                      child: Text('$n / hal', style: const TextStyle(fontSize: 11))),
              ],
              onChanged: (v) => ref
                  .read(manpowerManageFilterProvider.notifier)
                  .setPageSize(v ?? 25),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _drop('Dept', f.dept, d?.depts ?? const [], (v) =>
                ref.read(manpowerManageFilterProvider.notifier).setDept(v)),
            _dropEmpty('Section', f.section, d?.sections ?? const [], (v) =>
                ref.read(manpowerManageFilterProvider.notifier).setSection(v)),
            _dropEmpty('Crew', f.crew, d?.crews ?? const [], (v) =>
                ref.read(manpowerManageFilterProvider.notifier).setCrew(v)),
            _dropEmpty('Status', f.status, d?.statuses ?? const [], (v) =>
                ref.read(manpowerManageFilterProvider.notifier).setStatus(v)),
            OutlinedButton(
              onPressed: () {
                _search.clear();
                ref.read(manpowerManageFilterProvider.notifier).reset();
              },
              child: const Text('Reset', style: TextStyle(fontSize: 11.5)),
            ),
            if (canEdit)
              OutlinedButton(
                onPressed: () => _runAutofill(),
                child: const Text('Isi otomatis dari jabatan',
                    style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _drop(String label, String value, List<String> options,
      void Function(String) onChanged) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem(value: '', child: Text('Semua')),
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => onChanged(v ?? ''),
      ),
    );
  }

  Widget _dropEmpty(String label, String value, List<String> options,
      void Function(String) onChanged) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem(value: '', child: Text('Semua')),
          const DropdownMenuItem(
              value: manpowerEmpty, child: Text('(belum diisi)')),
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => onChanged(v ?? ''),
      ),
    );
  }

  Widget _body(ManpowerManage d, bool canEdit) {
    final classifiedPct =
        d.manpower > 0 ? (d.classified / d.manpower) * 100 : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kpiGrid(d, classifiedPct),
        const SizedBox(height: 12),
        _breakdown('Rincian per Section', d.bySection, isCrew: false),
        const SizedBox(height: 12),
        _breakdown('Rincian per Crew', d.byCrew, isCrew: true),
        const SizedBox(height: 12),
        if (canEdit && _selected.isNotEmpty) _bulkBar(d),
        _tableCard(d, canEdit),
      ],
    );
  }

  Widget _kpiGrid(ManpowerManage d, double classifiedPct) {
    final crewFilled =
        d.byCrew.where((c) => c.label != '(belum diisi)').toList();
    final crewCovered = crewFilled.fold<int>(0, (a, c) => a + c.total);
    double pctOf(int v, int base) => base > 0 ? (v / base) * 100 : 0;
    return LayoutBuilder(
      builder: (c, box) {
        final cols = box.maxWidth > 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.75,
          children: [
            ManpowerStatCard(
              title: 'Total Manpower — ${manpowerFmtPeriode(d.periode)}',
              value: mpNum(d.manpower),
              valueColor: const Color(0xFF2563EB),
              subtitle:
                  'orang (DEPT SPL2)${d.generalCrew > 0 ? ' · ${mpNum(d.assessed)} dinilai performanya' : ''}',
            ),
            ManpowerStatCard(
              title: 'Sudah Dikelompokkan',
              value: mpNum(d.classified),
              suffix: '/ ${mpNum(d.manpower)}',
              valueColor: const Color(0xFF16A34A),
              extra:
                  ManpowerBar(pct: classifiedPct, color: const Color(0xFF16A34A)),
              subtitle:
                  '${mpPct(classifiedPct)} · ${mpNum(d.unclassified)} belum lengkap',
            ),
            ManpowerStatCard(
              title: 'Staff',
              value: mpNum(d.staff),
              valueColor: const Color(0xFF1F2937),
              subtitle:
                  '${mpPct(pctOf(d.staff, d.assessed))} dari manpower dinilai',
            ),
            ManpowerStatCard(
              title: 'Mekanik',
              value: mpNum(d.mekanik),
              valueColor: const Color(0xFFD97706),
              subtitle:
                  '${mpPct(pctOf(d.mekanik, d.assessed))} dari manpower dinilai',
            ),
            ManpowerStatCard(
              title: 'Repairman',
              value: mpNum(d.repairman),
              valueColor: const Color(0xFF0891B2),
              subtitle:
                  '${mpPct(pctOf(d.repairman, d.assessed))} dari manpower dinilai',
            ),
            ManpowerStatCard(
              title: 'General Crew',
              value: mpNum(d.generalCrew),
              valueColor: const Color(0xFF6B7280),
              subtitle:
                  '${mpPct(pctOf(d.generalCrew, d.manpower))} dari manpower · tidak dihitung di performa',
            ),
            ManpowerStatCard(
              title: 'Cakupan Crew',
              value: mpNum(crewCovered),
              valueColor: const Color(0xFF2563EB),
              subtitle: '${crewFilled.length} dari ${d.crews.length} crew terisi',
            ),
          ],
        );
      },
    );
  }

  Widget _breakdown(String title, List<ManpowerBreakdown> rows,
      {bool isCrew = false}) {
    // Drill-down: klik label "Kelompok" → tabel "Data Manpower" di bawah
    // difilter ke kelompok itu (klik lagi = batalkan). Label kartu adalah
    // hasil derivasi (mis. crew NULL Dept Head tampil 'Dept Head'), jadi
    // dikirim ke backend sebagai section_label/crew_label.
    final f = ref.watch(manpowerManageFilterProvider);
    final picked = isCrew ? f.crewLabel : f.sectionLabel;
    final notifier = ref.read(manpowerManageFilterProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                headingRowHeight: 34,
                dataRowMinHeight: 30,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('Kelompok', style: _bh)),
                  DataColumn(label: Text('Staff', style: _bh), numeric: true),
                  DataColumn(label: Text('Mekanik', style: _bh), numeric: true),
                  DataColumn(label: Text('Repair', style: _bh), numeric: true),
                  DataColumn(label: Text('GenCrew', style: _bh), numeric: true),
                  DataColumn(label: Text('Belum', style: _bh), numeric: true),
                  DataColumn(label: Text('Total', style: _bh), numeric: true),
                ],
                rows: [
                  if (rows.isEmpty)
                    const DataRow(cells: [
                      DataCell(Text('Tidak ada data.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey))),
                    ]),
                  for (final b in rows)
                    DataRow(cells: [
                      DataCell(Text(
                          b.label == picked ? '${b.label} ●' : b.label,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontStyle: b.label == '(belum diisi)'
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: b.label == picked
                                  ? Theme.of(context).colorScheme.primary
                                  : b.label == '(belum diisi)'
                                      ? Colors.grey
                                      : null,
                              fontWeight: b.label == picked
                                  ? FontWeight.w700
                                  : b.label == '(belum diisi)'
                                      ? FontWeight.normal
                                      : FontWeight.w600)),
                          onTap: () => isCrew
                              ? notifier.setCrewPick(b.label)
                              : notifier.setSectionPick(b.label)),
                      DataCell(Text(mpNum(b.staff), style: _bc())),
                      DataCell(Text(mpNum(b.mekanik), style: _bc())),
                      DataCell(Text(mpNum(b.repairman), style: _bc())),
                      DataCell(Text(mpNum(b.generalCrew),
                          style: _bc(color: Colors.grey))),
                      DataCell(Text(mpNum(b.belum),
                          style: _bc(color: Colors.grey))),
                      DataCell(Text(mpNum(b.total), style: _bc(bold: true))),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ketuk kolom "Kelompok" untuk menampilkan kelompok itu di tabel Data Manpower.',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 2),
            Text(
              'Persentase performa memakai manpower dinilai (total dikurangi General Crew).',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulkBar(ManpowerManage d) {
    return _BulkBar(
      count: _selected.length,
      sections: d.sections,
      crews: d.crews,
      statuses: d.statuses,
      onApply: (section, crew, status) async {
        if (section.isEmpty && crew.isEmpty && status.isEmpty) {
          _setMsg('Pilih minimal satu nilai (Section/Crew/Status) untuk diterapkan.');
          return;
        }
        final body = <String, dynamic>{'nrps': _selected.toList()};
        if (section.isNotEmpty) body['section'] = section;
        if (crew.isNotEmpty) body['crew'] = crew;
        if (status.isNotEmpty) body['status'] = status;
        try {
          final n = await ref.read(manpowerApiProvider).bulkProfile(body);
          _setMsg('Pengelompokan ${mpNum(n)} orang diperbarui.');
          setState(() => _selected.clear());
          ref.read(manpowerManageTickProvider.notifier).bump();
        } catch (e) {
          _setMsg('gagal menyimpan: ${apiMessage(e)}');
        }
      },
      onCancel: () => setState(() => _selected.clear()),
    );
  }

  Widget _tableCard(ManpowerManage d, bool canEdit) {
    final f = ref.watch(manpowerManageFilterProvider);
    final pages = (d.total / f.pageSize).ceil().clamp(1, 999999);
    final allOnPage =
        d.data.isNotEmpty && d.data.every((r) => _selected.contains(r.nrp));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                      'Data Manpower — ${manpowerFmtPeriode(d.periode)} · ${mpNum(d.total)} orang',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                if (f.hasFilter)
                  TextButton(
                    onPressed: () => ref
                        .read(manpowerManageFilterProvider.notifier)
                        .reset(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Reset',
                        style: TextStyle(fontSize: 11.5)),
                  ),
              ],
            ),
            if (f.hasFilter)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    if (f.sectionLabel.isNotEmpty) 'Section: ${f.sectionLabel}',
                    if (f.crewLabel.isNotEmpty) 'Crew: ${f.crewLabel}',
                    if (f.section.isNotEmpty) 'Section: ${f.section}',
                    if (f.crew.isNotEmpty) 'Crew: ${f.crew}',
                    if (f.status.isNotEmpty) 'Status: ${f.status}',
                    if (f.search.isNotEmpty) '"${f.search}"',
                    if (f.dept.isNotEmpty) 'Dept: ${f.dept}',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
            const SizedBox(height: 8),
            if (canEdit)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: allOnPage,
                onChanged: (_) => setState(() {
                  if (allOnPage) {
                    for (final r in d.data) {
                      _selected.remove(r.nrp);
                    }
                  } else {
                    for (final r in d.data) {
                      _selected.add(r.nrp);
                    }
                  }
                }),
                title: const Text('Pilih semua di halaman ini',
                    style: TextStyle(fontSize: 11.5)),
              ),
            if (d.data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Tidak ada data sesuai filter.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              )
            else
              for (final r in d.data)
                _RowEditor(
                  row: r,
                  canEdit: canEdit,
                  selected: _selected.contains(r.nrp),
                  sections: d.sections,
                  crews: d.crews,
                  statuses: d.statuses,
                  onToggle: () => setState(() {
                    if (_selected.contains(r.nrp)) {
                      _selected.remove(r.nrp);
                    } else {
                      _selected.add(r.nrp);
                    }
                  }),
                  onSaved: (m) {
                    if (m != null) _setMsg(m);
                    ref.read(manpowerManageTickProvider.notifier).bump();
                  },
                  onMsg: _setMsg,
                ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Halaman ${f.page} dari $pages · ${mpNum(d.total)} baris',
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.grey.shade500)),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: f.page <= 1
                          ? null
                          : () => ref
                              .read(manpowerManageFilterProvider.notifier)
                              .setPage(f.page - 1),
                      child: const Text('Sebelumnya',
                          style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: f.page >= pages
                          ? null
                          : () => ref
                              .read(manpowerManageFilterProvider.notifier)
                              .setPage(f.page + 1),
                      child: const Text('Berikutnya',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _bh =
    TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey);

TextStyle _bc({bool bold = false, Color? color}) => TextStyle(
      fontSize: 11.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      color: color,
    );

/// Bar aksi massal (Section/Crew/Status untuk NRP terpilih).
class _BulkBar extends StatefulWidget {
  final int count;
  final List<String> sections;
  final List<String> crews;
  final List<String> statuses;
  final Future<void> Function(String section, String crew, String status) onApply;
  final VoidCallback onCancel;

  const _BulkBar({
    required this.count,
    required this.sections,
    required this.crews,
    required this.statuses,
    required this.onApply,
    required this.onCancel,
  });

  @override
  State<_BulkBar> createState() => _BulkBarState();
}

class _BulkBarState extends State<_BulkBar> {
  String _section = '';
  String _crew = '';
  String _status = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${mpNum(widget.count)} dipilih',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sel('Section', _section, widget.sections,
                  (v) => setState(() => _section = v)),
              _sel('Crew', _crew, widget.crews,
                  (v) => setState(() => _crew = v)),
              _sel('Status', _status, widget.statuses,
                  (v) => setState(() => _status = v)),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await widget.onApply(_section, _crew, _status);
                        if (mounted) setState(() => _busy = false);
                      },
                child: Text(_busy ? 'Menyimpan…' : 'Terapkan',
                    style: const TextStyle(fontSize: 12)),
              ),
              OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('Batal', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sel(String label, String value, List<String> options,
      void Function(String) onChanged) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem(value: '', child: Text('(tidak diubah)')),
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => onChanged(v ?? ''),
      ),
    );
  }
}

/// Baris edit inline pengelompokan satu orang.
class _RowEditor extends ConsumerStatefulWidget {
  final ManpowerProfileRow row;
  final bool canEdit;
  final bool selected;
  final List<String> sections;
  final List<String> crews;
  final List<String> statuses;
  final VoidCallback onToggle;
  final void Function(String? msg) onSaved;
  final void Function(String msg) onMsg;

  const _RowEditor({
    required this.row,
    required this.canEdit,
    required this.selected,
    required this.sections,
    required this.crews,
    required this.statuses,
    required this.onToggle,
    required this.onSaved,
    required this.onMsg,
  });

  @override
  ConsumerState<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends ConsumerState<_RowEditor> {
  late String _section;
  late String _crew;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _section = widget.row.section ?? '';
    _crew = widget.row.crew ?? '';
    _status = widget.row.status ?? '';
  }

  bool get _dirty =>
      _section != (widget.row.section ?? '') ||
      _crew != (widget.row.crew ?? '') ||
      _status != (widget.row.status ?? '');

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(manpowerApiProvider).updateProfile(widget.row.nrp, {
        'section': _section.isEmpty ? null : _section,
        'crew': _crew.isEmpty ? null : _crew,
        'status': _status.isEmpty ? null : _status,
      });
      widget.onSaved(
          'Pengelompokan ${widget.row.nama ?? widget.row.nrp} disimpan.');
    } catch (e) {
      widget.onMsg('gagal menyimpan: ${apiMessage(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _dirty ? const Color(0xFFFFFBEB) : Colors.transparent,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.canEdit)
                SizedBox(
                  width: 28,
                  child: Checkbox(
                    value: widget.selected,
                    onChanged: (_) => widget.onToggle(),
                  ),
                ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12.5),
                    children: [
                      TextSpan(
                          text: r.nama ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (r.autoFilled && (r.section ?? '').isNotEmpty)
                        const TextSpan(
                            text: '  auto',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                                backgroundColor: Color(0xFFF3F4F6))),
                    ],
                  ),
                ),
              ),
              Text('SS ${mpNum(r.ssClosed)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          Text(
            '${r.nrp} • ${r.jabatan ?? '-'} • ${r.dept ?? '-'}',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _field('Section', _section, widget.sections,
                  (v) => setState(() => _section = v))),
              const SizedBox(width: 6),
              Expanded(child: _field('Crew', _crew, widget.crews,
                  (v) => setState(() => _crew = v))),
              const SizedBox(width: 6),
              Expanded(child: _field('Status', _status, widget.statuses,
                  (v) => setState(() => _status = v))),
            ],
          ),
          if (widget.canEdit)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: (!_dirty || _saving) ? null : _save,
                child: Text(_saving ? '…' : 'Simpan',
                    style: const TextStyle(fontSize: 11.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, List<String> options,
      void Function(String) onChanged) {
    if (!widget.canEdit) {
      return Text('$label: ${value.isEmpty ? '—' : value}',
          style: const TextStyle(fontSize: 11));
    }
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        const DropdownMenuItem(value: '', child: Text('—')),
        for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}
