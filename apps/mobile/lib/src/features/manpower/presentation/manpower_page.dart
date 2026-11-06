import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../domain/manpower_models.dart';
import 'manpower_providers.dart';
import 'manpower_widgets.dart';

/// Manpower Inovasi — paritas web Manpower.tsx (KPI, tren, rincian dept, tabel).
class ManpowerPage extends ConsumerWidget {
  const ManpowerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(manpowerPeriodsProvider);

    // Set periode default sekali bila belum ada.
    ref.listen(manpowerPeriodsProvider, (_, next) {
      next.whenData((ps) {
        if (ref.read(manpowerPeriodeProvider).isEmpty && ps.isNotEmpty) {
          ref.read(manpowerPeriodeProvider.notifier).set(ps.first.periode);
        }
      });
    });
    periodsAsync.whenData((ps) {
      if (ref.read(manpowerPeriodeProvider).isEmpty && ps.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ref.read(manpowerPeriodeProvider).isEmpty) {
            ref.read(manpowerPeriodeProvider.notifier).set(ps.first.periode);
          }
        });
      }
    });

    return AppScaffold(
      title: 'Manpower Inovasi',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(manpowerPeriodsProvider);
          ref.invalidate(manpowerSummaryProvider);
          ref.invalidate(manpowerTrendProvider);
          ref.invalidate(manpowerRecordsProvider);
          await ref.read(manpowerSummaryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const _Filters(),
            const SizedBox(height: 8),
            Text(
              'Upload / update data manpower dilakukan di halaman Update Data (menu Operasional).',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),
            periodsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(manpowerPeriodsProvider)),
              data: (ps) {
                if (ps.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Belum ada data manpower. Upload file RptInnovatorMonthly <Bln> <Thn>.xlsx '
                        'di halaman Update Data (boleh sekaligus banyak bulan).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return const _Body();
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(manpowerPeriodsProvider);
    final periode = ref.watch(manpowerPeriodeProvider);
    final dept = ref.watch(manpowerDeptProvider);
    final summary = ref.watch(manpowerSummaryProvider).maybeWhen(
        data: (v) => v, orElse: () => null);

    final deptOptions = (summary?.dept ?? [])
        .map((d) => d.dept)
        .where((d) => d.isNotEmpty && d != '(kosong)')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: periode.isEmpty ? null : periode,
                isDense: true,
                decoration: const InputDecoration(
                    labelText: 'Bulan', isDense: true),
                items: periodsAsync.maybeWhen(
                  data: (ps) => [
                    for (final p in ps)
                      DropdownMenuItem(
                        value: p.periode,
                        child: Text(
                            '${manpowerFmtPeriode(p.periode)} — ${mpNum(p.manpower)} orang',
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  orElse: () => const <DropdownMenuItem<String>>[],
                ),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(manpowerPeriodeProvider.notifier).set(v);
                    ref.read(manpowerRecordsFilterProvider.notifier).setPage(1);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: dept,
                isDense: true,
                decoration:
                    const InputDecoration(labelText: 'Dept', isDense: true),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Semua')),
                  for (final d in deptOptions)
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) {
                  ref.read(manpowerDeptProvider.notifier).set(v ?? '');
                  ref.read(manpowerRecordsFilterProvider.notifier).setPage(1);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(manpowerSummaryProvider);
    final trendAsync = ref.watch(manpowerTrendProvider);
    final recordsAsync = ref.watch(manpowerRecordsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(manpowerSummaryProvider)),
          data: (s) {
            if (s == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kpiGrid(s),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Manpower vs Innovator SS per Bulan',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ManpowerTrendChart(
                            trend: trendAsync.maybeWhen(
                                data: (v) => v,
                                orElse: () => const <ManpowerPeriod>[])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _deptTable(s),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
        recordsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(manpowerRecordsProvider)),
          data: (page) => _recordsTable(page),
        ),
      ],
    );
  }

  Widget _kpiGrid(ManpowerSummary s) {
    return LayoutBuilder(
      builder: (c, box) {
        final cols = box.maxWidth > 640 ? 3 : 2;
        final double innovPct =
            s.assessed > 0 ? (s.innovatorAll / s.assessed) * 100 : 0;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            ManpowerStatCard(
              title: 'Karyawan Sudah Berinovasi',
              value: mpNum(s.innovatorAll),
              suffix: '/ ${mpNum(s.assessed)} orang',
              valueColor: const Color(0xFF2563EB),
              extra: ManpowerBar(pct: innovPct, color: const Color(0xFF2563EB)),
              subtitle:
                  '${mpPct(innovPct)} dinilai · ${mpNum(s.innovatorSs)} via SS',
            ),
            ManpowerStatCard(
              title: 'Manpower — ${manpowerFmtPeriode(s.periode)}',
              value: mpNum(s.manpower),
              valueColor: const Color(0xFF2563EB),
              subtitle:
                  '${s.dept.length} dept${s.generalCrew > 0 ? ' · ${mpNum(s.generalCrew)} General Crew' : ''}',
            ),
            ManpowerStatCard(
              title: 'Innovator SS',
              value: mpNum(s.innovatorSs),
              valueColor: const Color(0xFF16A34A),
              subtitle:
                  'coverage ${mpPct(s.coveragePct)} dari ${mpNum(s.assessed)} dinilai',
            ),
            ManpowerStatCard(
              title: 'SS Closed',
              value: mpNum(s.ssClosed),
              valueColor: const Color(0xFF1F2937),
              subtitle: '${mpRatio(s.ssPerManpower)} SS per manpower',
            ),
            ManpowerStatCard(
              title: 'DT / QCP / QCC Closed',
              value: '${mpNum(s.dtClosed)} / ${mpNum(s.qcpClosed)} / ${mpNum(s.qccClosed)}',
              valueColor: const Color(0xFF1F2937),
              subtitle: 'akumulasi bulan ini',
            ),
          ],
        );
      },
    );
  }

  Widget _deptTable(ManpowerSummary s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rincian per Dept — ${manpowerFmtPeriode(s.periode)}',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
            Text(
              'General Crew dikecualikan dari kolom Dinilai, coverage, dan SS per manpower.',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                headingRowHeight: 34,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('Dept', style: _h)),
                  DataColumn(label: Text('Manpower', style: _h), numeric: true),
                  DataColumn(label: Text('Gen Crew', style: _h), numeric: true),
                  DataColumn(label: Text('Dinilai', style: _h), numeric: true),
                  DataColumn(label: Text('Inov SS', style: _h), numeric: true),
                  DataColumn(label: Text('Coverage', style: _h)),
                  DataColumn(label: Text('SS Closed', style: _h), numeric: true),
                  DataColumn(label: Text('SS/Mp', style: _h), numeric: true),
                ],
                rows: [
                  for (final d in s.dept)
                    DataRow(cells: [
                      DataCell(Text(d.dept, style: _cell(bold: true))),
                      DataCell(Text(mpNum(d.manpower), style: _cell())),
                      DataCell(Text(mpNum(d.generalCrew),
                          style: _cell(color: Colors.grey))),
                      DataCell(Text(mpNum(d.assessed), style: _cell())),
                      DataCell(Text(mpNum(d.innovatorSs), style: _cell())),
                      DataCell(SizedBox(
                        width: 110,
                        child: Row(
                          children: [
                            SizedBox(
                                width: 52,
                                child: ManpowerBar(pct: d.coveragePct)),
                            const SizedBox(width: 6),
                            Text(mpPct(d.coveragePct),
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      )),
                      DataCell(Text(mpNum(d.ssClosed), style: _cell())),
                      DataCell(Text(mpRatio(d.ssPerManpower), style: _cell())),
                    ]),
                  DataRow(
                    cells: [
                      DataCell(Text('Total', style: _cell(bold: true))),
                      DataCell(Text(mpNum(s.manpower), style: _cell(bold: true))),
                      DataCell(Text(mpNum(s.generalCrew),
                          style: _cell(bold: true, color: Colors.grey))),
                      DataCell(Text(mpNum(s.assessed), style: _cell(bold: true))),
                      DataCell(
                          Text(mpNum(s.innovatorSs), style: _cell(bold: true))),
                      DataCell(Text(mpPct(s.coveragePct),
                          style: const TextStyle(fontSize: 11, color: Colors.grey))),
                      DataCell(Text(mpNum(s.ssClosed), style: _cell(bold: true))),
                      DataCell(
                          Text(mpRatio(s.ssPerManpower), style: _cell(bold: true))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordsTable(ManpowerRecordPage page) {
    return Consumer(builder: (context, ref, _) {
      final f = ref.watch(manpowerRecordsFilterProvider);
      final pages = (page.total / f.pageSize).ceil().clamp(1, 999999);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data Manpower · ${mpNum(page.total)} orang',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                    hintText: 'Cari nama / NRP / jabatan…', isDense: true),
                onSubmitted: (v) => ref
                    .read(manpowerRecordsFilterProvider.notifier)
                    .setSearch(v.trim()),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: f.innovatorOnly,
                      onChanged: (v) => ref
                          .read(manpowerRecordsFilterProvider.notifier)
                          .setInnovatorOnly(v ?? false),
                      title: const Text('Hanya innovator SS',
                          style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                  DropdownButton<int>(
                    value: f.pageSize,
                    items: [
                      for (final n in [25, 50, 100])
                        DropdownMenuItem(
                            value: n,
                            child: Text('$n / hal',
                                style: const TextStyle(fontSize: 11))),
                    ],
                    onChanged: (v) => ref
                        .read(manpowerRecordsFilterProvider.notifier)
                        .setPageSize(v ?? 25),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (page.data.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('Tidak ada data.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                )
              else
                for (final r in page.data) _recordTile(r),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Halaman ${f.page} dari $pages · ${mpNum(page.total)} baris',
                      style: TextStyle(
                          fontSize: 10.5, color: Colors.grey.shade500)),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: f.page <= 1
                            ? null
                            : () => ref
                                .read(manpowerRecordsFilterProvider.notifier)
                                .setPage(f.page - 1),
                        child: const Text('Sebelumnya',
                            style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: f.page >= pages
                            ? null
                            : () => ref
                                .read(manpowerRecordsFilterProvider.notifier)
                                .setPage(f.page + 1),
                        child:
                            const Text('Berikutnya', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _recordTile(ManpowerRecord r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.nama ?? '-',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              if (r.innovatorSs > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(999)),
                  child: const Text('SS',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D))),
                ),
            ],
          ),
          Text(
            '${r.nrp} • ${r.jabatan ?? '-'} • ${r.dept ?? '-'}${(r.divisi ?? '').isNotEmpty ? ' • ${r.divisi}' : ''}',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
          Text('SS Closed: ${mpNum(r.ssClosed)}',
              style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

const TextStyle _h =
    TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey);

TextStyle _cell({bool bold = false, Color? color}) => TextStyle(
      fontSize: 11.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      color: color,
    );
