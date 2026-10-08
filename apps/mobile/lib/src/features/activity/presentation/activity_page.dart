import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/auth/token_storage.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../data/activity_api.dart';
import '../domain/activity_models.dart';
import 'activity_providers.dart';

const _idMonthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];
const _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

class CalendarCell {
  final String iso;
  final int n;
  final bool inMonth;
  final int y;
  final int m;
  const CalendarCell(this.iso, this.n, this.inMonth, this.y, this.m);
}

/// Grid kalender port web Pages.tsx: minggu mulai Senin, dot jumlah.
List<CalendarCell> buildCells(int y, int m) {
  final first = DateTime(y, m, 1);
  final lead = (first.weekday + 6) % 7;
  final daysIn = DateTime(y, m + 1, 0).day;
  var total = lead + daysIn;
  while (total % 7 != 0) {
    total++;
  }
  final start = first.subtract(Duration(days: lead));
  return List.generate(total, (i) {
    final d = start.add(Duration(days: i));
    return CalendarCell(toApiDate(d), d.day, d.month == m, d.year, d.month);
  });
}

/// Activity: tab Kalender + Rekap, filter crew/kategori. Meniru ActivityPage web.
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  int _tab = 0;
  late final TextEditingController _crew;
  late final TextEditingController _cat;

  @override
  void initState() {
    super.initState();
    final f = ref.read(activityFilterProvider);
    _crew = TextEditingController(text: f.crew);
    _cat = TextEditingController(text: f.category);
  }

  @override
  void dispose() {
    _crew.dispose();
    _cat.dispose();
    super.dispose();
  }

  void _applyFilter() {
    ref.read(activityFilterProvider.notifier).setCrew(_crew.text.trim());
    ref.read(activityFilterProvider.notifier).setCategory(_cat.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final ym = ref.watch(activityMonthProvider);
    final canAdd = ref.watch(authProvider).can('activity', 'add');

    return AppScaffold(
      title: 'Activity',
      actions: [
        if (canAdd && _tab == 0)
          IconButton(
            tooltip: 'Tambah',
            icon: const Icon(Icons.add),
            onPressed: () {
              final sel = ref.read(selectedDateProvider);
              context.push('/activity/new?date=$sel');
            },
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Kalender')),
                      ButtonSegment(value: 1, label: Text('Rekap')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _crew,
                    decoration: const InputDecoration(
                      labelText: 'Crew: semua',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _cat,
                    decoration: const InputDecoration(
                      labelText: 'Kategori: semua',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _applyFilter, child: const Text('Tampilkan')),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _CalendarTab(ym: ym, ref: ref)
                : const _RecapTab(),
          ),
        ],
      ),
    );
  }
}

class _CalendarTab extends ConsumerWidget {
  final ActivityMonth ym;
  final WidgetRef ref;
  const _CalendarTab({required this.ym, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedDateProvider);
    final countsAsync = ref.watch(monthCountsProvider);
    final today = toApiDate(DateTime.now());
    final cells = buildCells(ym.year, ym.month);
    final notifier = ref.read(activityMonthProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthCountsProvider);
        ref.invalidate(dayItemsProvider);
        await ref.read(dayItemsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(onPressed: () => notifier.shift(-1), child: const Text('‹')),
              Text('${_idMonthNames[ym.month - 1]} ${ym.year}',
                  style: Theme.of(context).textTheme.titleMedium),
              OutlinedButton(onPressed: () => notifier.shift(1), child: const Text('›')),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final d in _dayNames)
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          countsAsync.when(
            data: (counts) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemCount: cells.length,
              itemBuilder: (c, i) {
                final cell = cells[i];
                final n = counts[cell.iso] ?? 0;
                final selected = sel == cell.iso;
                return InkWell(
                  onTap: () {
                    if (!cell.inMonth) {
                      ref.read(activityMonthProvider.notifier).jump(cell.y, cell.m);
                    }
                    ref.read(selectedDateProvider.notifier).select(cell.iso);
                  },
                  child: Opacity(
                    opacity: cell.inMonth ? 1 : 0.4,
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${cell.n}',
                            style: TextStyle(
                              fontWeight: cell.iso == today ? FontWeight.bold : null,
                              color: cell.iso == today
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          if (n > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$n',
                                  style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(monthCountsProvider),
            ),
          ),
          const SizedBox(height: 12),
          Text(fmtDate(sel), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          _DayList(sel: sel),
        ],
      ),
    );
  }
}

class _DayList extends ConsumerWidget {
  final String sel;
  const _DayList({required this.sel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(dayItemsProvider);
    final tokenAsync = ref.watch(accessTokenProvider);

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Belum ada aktivitas.')),
          );
        }
        final token = switch (tokenAsync) {
          AsyncData(:final value) => value,
          _ => null,
        };
        return Column(
          children: [
            for (final a in items)
              _ActivityTile(activity: a, token: token),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(dayItemsProvider),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Activity activity;
  final String? token;
  const _ActivityTile({required this.activity, required this.token});

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final sub = [
      if ((a.crew ?? '').isNotEmpty) a.crew!,
      if ((a.category ?? '').isNotEmpty) a.category!,
      if ((a.cn ?? '').isNotEmpty) a.cn!,
    ].join(' • ');
    final withPhotos = sub.isEmpty
        ? '${a.photoCount} foto'
        : '$sub • ${a.photoCount} foto';
    return Card(
      child: ListTile(
        leading: (a.coverId != null && token != null)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ActivityApi.photoUrl(a.id, a.coverId!, token!),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                ),
              )
            : const Icon(Icons.event_note),
        title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(withPhotos, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => context.push('/activity/${a.id}'),
      ),
    );
  }
}

class _RecapTab extends ConsumerWidget {
  const _RecapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recapAsync = ref.watch(recapProvider);
    return recapAsync.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('Belum ada aktivitas untuk filter ini.'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recapProvider);
            await ref.read(recapProvider.future);
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('Judul')),
                  DataColumn(label: Text('Crew')),
                  DataColumn(label: Text('Kategori')),
                  DataColumn(label: Text('CN')),
                  DataColumn(label: Text('HM')),
                  DataColumn(label: Text('Foto'), numeric: true),
                ],
                rows: [
                  for (final a in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(fmtDate(a.date))),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(a.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          onTap: () => context.push('/activity/${a.id}'),
                        ),
                        DataCell(Text(a.crew ?? '-')),
                        DataCell(Text(a.category ?? '-')),
                        DataCell(Text(a.cn ?? '-')),
                        DataCell(Text(a.hm != null ? '${a.hm}' : '-')),
                        DataCell(Text('${a.photoCount}')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(recapProvider),
      ),
    );
  }
}
