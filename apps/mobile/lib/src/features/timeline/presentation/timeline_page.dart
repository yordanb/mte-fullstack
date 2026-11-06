// Halaman Timeline Mingguan — paritas tampilan web Timeline.tsx:
// rentang tanggal (maks 31 hari) + filter crew/kategori + ringkasan +
// infografis kapsul hari + detail kegiatan per tanggal (foto/video).
//
// Memakai ulang lapisan data Activity (fetchActivitiesByDate/fetchActivity).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/utils/date_fmt.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../activity/data/activity_api.dart';
import '../../activity/domain/activity_models.dart';
import '../../activity/presentation/activity_video.dart';

const List<String> timelineCrews = ['Pumping', 'Lighting', 'Mobile', 'Grader', 'PCH'];
const List<String> timelineCats = ['Proker', 'FUI', 'USM', 'SCM'];

/// Batas maksimal hari rentang (web MAX_DAYS = 31).
const int timelineMaxDays = 31;

/// Palet kapsul hari ala template web Timeline.tsx:16.
const List<Color> timelineDayColors = [
  Color(0xFFF0506E),
  Color(0xFF5B5BD6),
  Color(0xFFFFC531),
  Color(0xFF1E88E5),
  Color(0xFFFF8A3D),
  Color(0xFF6A3FA0),
  Color(0xFF8BC34A),
];

const List<String> _idDays = [
  'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'
];
const List<String> _idMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];

/// Daftar ISO (YYYY-MM-DD) dari `from` s/d `to`, maksimal [timelineMaxDays].
List<String> timelineRangeDates(String from, String to) {
  final out = <String>[];
  var cur = DateTime.parse(from);
  final end = DateTime.parse(to);
  while (!cur.isAfter(end) && out.length < timelineMaxDays) {
    out.add(toApiDate(cur));
    cur = cur.add(const Duration(days: 1));
  }
  return out;
}

/// "Minggu, 3 November 2026" (web fmtDay).
String timelineFmtDay(String iso) {
  final d = DateTime.parse(iso);
  return '${_idDays[d.weekday % 7]}, ${d.day} ${_idMonths[d.month - 1]} ${d.year}';
}

/// "Minggu" (web dayName).
String timelineDayName(String iso) => _idDays[DateTime.parse(iso).weekday % 7];

/// "3/11" (web dayNum).
String timelineDayNum(String iso) {
  final d = DateTime.parse(iso);
  return '${d.day}/${d.month}';
}

/// Filter rentang + crew/kategori (nilai terpasang, bukan sedang diketik).
class TimelineFilter {
  final String df;
  final String dt;
  final String crew;
  final String cat;

  const TimelineFilter({
    required this.df,
    required this.dt,
    this.crew = '',
    this.cat = '',
  });

  TimelineFilter copyWith({String? df, String? dt, String? crew, String? cat}) =>
      TimelineFilter(
        df: df ?? this.df,
        dt: dt ?? this.dt,
        crew: crew ?? this.crew,
        cat: cat ?? this.cat,
      );
}

/// Default 7 hari terakhir (web todayLocal(6) s/d todayLocal()).
TimelineFilter defaultTimelineFilter() {
  final now = DateTime.now();
  final df = now.subtract(const Duration(days: 6));
  return TimelineFilter(df: toApiDate(df), dt: toApiDate(now));
}

class TimelineFilterNotifier extends Notifier<TimelineFilter> {
  @override
  TimelineFilter build() => defaultTimelineFilter();

  void apply({
    String? df,
    String? dt,
    String? crew,
    String? cat,
  }) =>
      state = state.copyWith(df: df, dt: dt, crew: crew, cat: cat);
}

final timelineFilterProvider =
    NotifierProvider<TimelineFilterNotifier, TimelineFilter>(
        TimelineFilterNotifier.new);

/// Kegiatan per tanggal (filter crew/kategori client-side seperti web).
class TimelineDay {
  final String date;
  final List<Activity> items;
  const TimelineDay({required this.date, required this.items});
}

final timelineDaysProvider = FutureProvider<List<TimelineDay>>((ref) async {
  final f = ref.watch(timelineFilterProvider);
  if (DateTime.parse(f.dt).isBefore(DateTime.parse(f.df))) {
    throw Exception('Tanggal akhir sebelum tanggal awal.');
  }
  final api = ref.watch(activityApiProvider);
  final dates = timelineRangeDates(f.df, f.dt);
  final cw = f.crew.trim().toLowerCase();
  final ct = f.cat.trim().toLowerCase();
  final perDay = await Future.wait(dates.map((d) async {
    try {
      return await api.byDate(d);
    } catch (_) {
      return <Activity>[];
    }
  }));
  return [
    for (var i = 0; i < dates.length; i++)
      TimelineDay(
        date: dates[i],
        items: perDay[i].where((a) {
          final okCrew =
              cw.isEmpty || (a.crew ?? '').toLowerCase().contains(cw);
          final okCat =
              ct.isEmpty || (a.category ?? '').toLowerCase().contains(ct);
          return okCrew && okCat;
        }).toList(),
      ),
  ];
});

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  String? _openId;
  List<ActivityPhoto> _photos = const [];
  bool _loadingPhotos = false;
  final _crewCtl = TextEditingController();
  final _catCtl = TextEditingController();
  bool _ctlInit = false;

  @override
  void dispose() {
    _crewCtl.dispose();
    _catCtl.dispose();
    super.dispose();
  }

  Future<void> _togglePhotos(Activity a) async {
    if (_openId == a.id) {
      setState(() {
        _openId = null;
        _photos = const [];
      });
      return;
    }
    setState(() {
      _openId = a.id;
      _photos = const [];
      _loadingPhotos = true;
    });
    try {
      final det = await ref.read(activityApiProvider).detail(a.id);
      if (!mounted || _openId != a.id) return;
      setState(() {
        _photos = det.photos;
        _loadingPhotos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPhotos = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final f = ref.read(timelineFilterProvider);
    final initial = DateTime.parse(isStart ? f.df : f.dt);
    final p = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p == null) return;
    final notifier = ref.read(timelineFilterProvider.notifier);
    if (isStart) {
      notifier.apply(df: toApiDate(p));
    } else {
      notifier.apply(dt: toApiDate(p));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(timelineFilterProvider);
    final daysAsync = ref.watch(timelineDaysProvider);
    final canView = ref.watch(authProvider).can('timeline', 'view');

    if (!canView) {
      return const AppScaffold(
        title: 'Timeline Mingguan',
        body: Center(child: Text('Tidak punya akses Timeline.')),
      );
    }

    final days = daysAsync.value ?? const <TimelineDay>[];
    final all = days.expand((d) => d.items).toList();
    final activeDays = days.where((d) => d.items.isNotEmpty).length;
    final photoTotal = all.fold<int>(0, (n, a) => n + a.photoCount);

    return AppScaffold(
      title: 'Timeline Mingguan',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(timelineDaysProvider);
          await ref.read(timelineDaysProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _filterCard(f),
            const SizedBox(height: 8),
            _summaryRow(
                all.length, '$activeDays/${days.length}', photoTotal, f.crew),
            const SizedBox(height: 8),
            daysAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Memuat timeline...',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              error: (e, _) => Text('$e',
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
              data: (days) => days.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Tidak ada hari pada rentang ini.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _capsuleStrip(days),
                        const SizedBox(height: 12),
                        for (final d in days) _daySection(d),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Toolbar filter + aksi ───────────────────────────────────────
  Widget _filterCard(TimelineFilter f) {
    final notifier = ref.read(timelineFilterProvider.notifier);
    if (!_ctlInit) {
      _crewCtl.text = f.crew;
      _catCtl.text = f.cat;
      _ctlInit = true;
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dateChip('Dari', f.df, () => _pickDate(isStart: true)),
                _dateChip('Sampai', f.dt, () => _pickDate(isStart: false)),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _crewCtl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Crew',
                      hintText: 'semua',
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _catCtl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => notifier.apply(
                      crew: _crewCtl.text.trim(), cat: _catCtl.text.trim()),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12)),
                  child: const Text('Tampilkan', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton(
                  onPressed: () => ref.invalidate(timelineDaysProvider),
                  child: const Text('Muat ulang',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final c in timelineCrews)
                  ActionChip(
                    label: Text(c, style: const TextStyle(fontSize: 10.5)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final next = f.crew == c ? '' : c;
                      _crewCtl.text = next;
                      notifier.apply(crew: next);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(String label, String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            labelStyle: const TextStyle(fontSize: 11),
          ),
          child: Text(fmtDate(value), style: const TextStyle(fontSize: 12)),
        ),
      );

  Widget _summaryRow(int kegiatan, String hariAktif, int foto, String crew) {
    Widget item(String v, String label) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(v,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          item('$kegiatan', 'kegiatan'),
          item(hariAktif, 'hari aktif'),
          item('$foto', 'foto'),
          item(crew.isEmpty ? 'Semua' : crew, 'crew'),
        ],
      ),
    );
  }

  // ── Infografis kapsul hari (versi ringkas untuk mobile) ─────────
  Widget _capsuleStrip(List<TimelineDay> days) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Timeline',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = days[i];
                  final color = timelineDayColors[i % timelineDayColors.length];
                  return Container(
                    width: 110,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${timelineDayName(d.date)} '
                            '${timelineDayNum(d.date)}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const Spacer(),
                        Text('${d.items.length}',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const Text('kegiatan',
                            style: TextStyle(
                                fontSize: 9.5, color: Colors.white70)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail per tanggal ──────────────────────────────────────────
  Widget _daySection(TimelineDay d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(timelineFmtDay(d.date),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${d.items.length} kegiatan',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (d.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Tidak ada kegiatan.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            for (final a in d.items) _activityCard(a),
        ],
      ),
    );
  }

  Widget _activityCard(Activity a) {
    final token = ref.watch(accessTokenProvider).value;
    final photoCount = a.photoCount;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cover(a, token),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      a.crew,
                      a.category,
                      a.cn,
                    ].where((v) => v != null && v.isNotEmpty).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if ((a.description ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(a.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                    ),
                  if (photoCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: () => _togglePhotos(a),
                        child: Text(
                          _openId == a.id
                              ? 'Sembunyikan foto'
                              : 'Lihat $photoCount foto',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  if (_openId == a.id)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _photoGrid(a, token),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(Activity a, String? token) {
    const size = 76.0;
    if (a.coverId == null || token == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.image_not_supported, color: Colors.grey.shade400),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        ActivityApi.photoUrl(a.id, a.coverId!, token),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade200,
          child: Icon(Icons.broken_image, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget _photoGrid(Activity a, String? token) {
    if (_loadingPhotos) {
      return const SizedBox(
        height: 40,
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (token == null) {
      return const Text('Tidak bisa memuat foto.',
          style: TextStyle(fontSize: 11, color: Colors.grey));
    }
    if (_photos.isEmpty) {
      return const Text('Memuat foto...',
          style: TextStyle(fontSize: 11, color: Colors.grey));
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (final p in _photos)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.isVideo
                ? VideoThumb(
                    width: double.infinity,
                    height: double.infinity,
                    url: ActivityApi.photoUrl(a.id, p.id, token),
                    onTap: () => showVideoDialog(
                      context,
                      url: ActivityApi.photoUrl(a.id, p.id, token),
                      title: p.origName,
                    ),
                  )
                : Image.network(
                    ActivityApi.photoUrl(a.id, p.id, token),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(Icons.broken_image,
                          color: Colors.grey.shade400),
                    ),
                  ),
          ),
      ],
    );
  }
}
