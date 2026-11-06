import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart' show apiMessage;
import '../data/staging_api.dart';
import '../domain/staging_models.dart';
import 'staging_providers.dart';

/// Dialog tambah grup staging (web AddGroupModal) — format cepat + detail.
Future<void> showAddGroupDialog(
    BuildContext context, WidgetRef ref, String period) async {
  final quick = TextEditingController();
  final groupNo = TextEditingController();
  final sump = TextEditingController();
  final sistem = TextEditingController();
  final chain = TextEditingController();
  var busy = false;
  var msg = '';
  var warnCN = <String>[];

  // No urut grup baru = grup terakhir + 1.
  final groups = ref.read(stagingGroupsProvider).maybeWhen(
      data: (v) => v, orElse: () => const <StagingGroup>[]);
  final nextNo = groups.isEmpty
      ? 1
      : groups.map((g) => g.groupNo).reduce((a, b) => a > b ? a : b) + 1;
  groupNo.text = '$nextNo';

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) {
        final parsed = stagingParseQuickGroup(quick.text);
        final cns = stagingParseChain(chain.text);
        return AlertDialog(
          title: const Text('Tambah Grup Staging'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: quick,
                  decoration: const InputDecoration(
                    labelText: 'Format cepat — paste teks berikut',
                    hintText: 'Sump C3 [Transfer] - WP764 - WP1126 - WP1066',
                  ),
                  onChanged: (v) {
                    final p = stagingParseQuickGroup(v);
                    setSt(() {
                      if (p != null) {
                        sump.text = p.sump;
                        sistem.text = p.system;
                        chain.text = p.cn.join(' - ');
                      }
                    });
                  },
                ),
                if (quick.text.trim().isNotEmpty && parsed == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Format: nama [Sistem] - CN pump - CN pump … — sistem dalam [ kurung siku ].',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD97706)),
                    ),
                  ),
                if (parsed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Terbaca: Sump ${parsed.sump} • Sistem ${parsed.system} • ${parsed.cn.length} pump berurutan',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF047857)),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: groupNo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'No urut', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sump,
                  decoration: const InputDecoration(
                      labelText: 'Nama Sump', hintText: 'cth SUMP D1',
                      isDense: true),
                ),
                const SizedBox(height: 8),
                _systemField(sistem),
                const SizedBox(height: 8),
                TextField(
                  controller: chain,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Pump berurutan (Primer → Booster)',
                    hintText: 'WP764 - WP1126 - WP1066',
                    isDense: true,
                  ),
                  onChanged: (_) => setSt(() => msg = ''),
                ),
                if (cns.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < cns.length; i++)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              i == 0
                                  ? '${cns[i]} (Primer)'
                                  : '${cns[i]} (Booster $i)',
                              style: const TextStyle(fontSize: 10.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (warnCN.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Tidak ditemukan di master equipment (PUMPING): ${warnCN.join(', ')} — perbaiki daftar pump.',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFDC2626)),
                    ),
                  ),
                if (msg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(msg,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(c),
                child: const Text('Batal')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setSt(() {
                        msg = '';
                        warnCN = [];
                      });
                      if (sistem.text.trim().isEmpty) {
                        setSt(() => msg = 'Sistem pemompaan wajib diisi');
                        return;
                      }
                      setSt(() => busy = true);
                      final api = ref.read(stagingApiProvider);
                      try {
                        // Pra-validasi CN di master equipment (kategori PUMPING).
                        if (cns.isNotEmpty) {
                          final bad = <String>[];
                          for (final cn in cns) {
                            final ok = await api.equipmentExists(cn);
                            if (!ok) bad.add(cn);
                          }
                          if (bad.isNotEmpty) {
                            setSt(() {
                              warnCN = bad;
                              busy = false;
                            });
                            return;
                          }
                        }
                        final gid = await api.createGroup({
                          'group_no': int.tryParse(groupNo.text.trim()) ?? nextNo,
                          'sump_name':
                              sump.text.trim().isEmpty ? null : sump.text.trim(),
                          'system_type': sistem.text.trim(),
                          'is_active': true,
                        });
                        final failed = <String>[];
                        for (var i = 0; i < cns.length; i++) {
                          try {
                            await api.addPump(gid,
                                pumpCn: cns[i], roleOrder: i, period: period);
                          } catch (_) {
                            failed.add(cns[i]);
                          }
                        }
                        ref.read(stagingTickProvider.notifier).bump();
                        if (c.mounted) {
                          if (failed.isEmpty) {
                            Navigator.pop(c);
                          } else {
                            setSt(() {
                              busy = false;
                              msg =
                                  'Grup dibuat. Pump gagal masuk: ${failed.join(', ')} — tambahkan manual atau hapus grup lalu ulangi.';
                            });
                          }
                        }
                      } catch (e) {
                        setSt(() {
                          busy = false;
                          msg = 'gagal: ${apiMessage(e)}';
                        });
                      }
                    },
              child: Text(busy ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        );
      },
    ),
  );
}

/// Dialog ubah grup (web EditGroupModal).
Future<void> showEditGroupDialog(
    BuildContext context, WidgetRef ref, StagingGroup group) async {
  final groupNo = TextEditingController(text: '${group.groupNo}');
  final sump = TextEditingController(text: group.sumpName ?? '');
  final sistem = TextEditingController(text: group.systemType);
  var aktif = group.isActive;
  var msg = '';

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: const Text('Ubah Grup Staging'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupNo,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'No urut', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sump,
                decoration: const InputDecoration(
                    labelText: 'Nama Sump', hintText: 'cth SUMP D1',
                    isDense: true),
              ),
              const SizedBox(height: 8),
              _systemField(sistem),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: aktif,
                onChanged: (v) => setSt(() => aktif = v ?? true),
                title: const Text('Aktif', style: TextStyle(fontSize: 12.5)),
              ),
              if (msg.isNotEmpty)
                Text(msg,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFFDC2626))),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(stagingApiProvider).patchGroup(group.id, {
                  'group_no': int.tryParse(groupNo.text.trim()) ?? group.groupNo,
                  'sump_name': sump.text.trim().isEmpty ? null : sump.text.trim(),
                  'system_type': sistem.text.trim(),
                  'is_active': aktif,
                });
                ref.read(stagingTickProvider.notifier).bump();
                if (c.mounted) Navigator.pop(c);
              } catch (e) {
                setSt(() => msg = 'gagal: ${apiMessage(e)}');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog pindah pump ke grup lain (web MovePumpModal, tanpa drag).
Future<void> showMovePumpDialog(
  BuildContext context,
  WidgetRef ref,
  StagingPump pump,
  int currentGroupId,
  List<StagingGroup> groups,
) async {
  final curGrp = groups.where((g) => g.id == currentGroupId).firstOrNull;
  final others =
      groups.where((g) => g.id != currentGroupId && g.isActive).toList();
  if (others.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Pindah ${pump.pumpCn}'),
        content: const Text(
            'Belum ada grup aktif lain sebagai tujuan. Buat grup baru dulu lewat "+ Tambah Grup".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
        ],
      ),
    );
    return;
  }

  var gid = others.first.id;
  var role = _lastRoleFor(others.first);
  var msg = '';

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) {
        final target = others.where((g) => g.id == gid).firstOrNull;
        final positions = target == null ? <({int value, String label})>[] : _positions(target);
        return AlertDialog(
          title: Text('Pindah ${pump.pumpCn}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dari: Grup ${curGrp?.groupNo ?? '-'} (${curGrp?.systemType ?? '-'}) — ${pump.roleLabel}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: gid,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Grup tujuan', isDense: true),
                  items: [
                    for (final g in others)
                      DropdownMenuItem(
                        value: g.id,
                        child: Text(
                          'Grup ${g.groupNo} — ${g.sumpClean.isEmpty ? '(tanpa sump)' : g.sumpClean} [${g.systemType}] (${g.pumps.length} pump)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setSt(() {
                      gid = v ?? gid;
                      final t = others.where((g) => g.id == gid).firstOrNull;
                      role = t == null ? role : _lastRoleFor(t);
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: positions.any((p) => p.value == role)
                      ? role
                      : (positions.isNotEmpty ? positions.last.value : null),
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Posisi di grup tujuan', isDense: true),
                  items: [
                    for (final p in positions)
                      DropdownMenuItem(
                        value: p.value,
                        child: Text(p.label, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) => setSt(() => role = v ?? role),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Pump yang dilewati akan bergeser satu posisi ke belakang. Riwayat pindah dicatat otomatis.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                if (msg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(msg,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(stagingApiProvider).movePump(pump.id, gid, role);
                  ref.read(stagingTickProvider.notifier).bump();
                  if (c.mounted) Navigator.pop(c);
                } catch (e) {
                  setSt(() => msg = 'gagal: ${apiMessage(e)}');
                }
              },
              child: const Text('Pindahkan'),
            ),
          ],
        );
      },
    ),
  );
}

/// Dialog copy konfigurasi (web CopyModal).
Future<void> showCopyDialog(
    BuildContext context, WidgetRef ref, String curPeriod) async {
  var from = stagingShiftPeriod(curPeriod, -1);
  var msg = '';

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: const Text('Copy Konfigurasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salin ke ${stagingPeriodLabel(curPeriod)}.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Dari:', style: TextStyle(fontSize: 12.5)),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () =>
                      setSt(() => from = stagingShiftPeriod(from, -1)),
                  child: const Text('‹'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(stagingPeriodLabel(from),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                OutlinedButton(
                  onPressed: () =>
                      setSt(() => from = stagingShiftPeriod(from, 1)),
                  child: const Text('›'),
                ),
              ],
            ),
            if (msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(msg,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(stagingApiProvider)
                    .copyConfig(from, curPeriod);
                ref.read(stagingTickProvider.notifier).bump();
                if (c.mounted) Navigator.pop(c);
              } catch (e) {
                setSt(() => msg = 'gagal: ${apiMessage(e)}');
              }
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    ),
  );
}

int _lastRoleFor(StagingGroup g) {
  if (g.pumps.isEmpty) return 0;
  return g.pumps.map((p) => p.roleOrder).reduce((a, b) => a > b ? a : b) + 1;
}

List<({int value, String label})> _positions(StagingGroup target) {
  final opts = <({int value, String label})>[];
  for (var i = 0; i < target.pumps.length; i++) {
    final p = target.pumps[i];
    opts.add((
      value: p.roleOrder,
      label:
          'Posisi ${i + 1} — ${p.roleOrder == 0 ? 'Primer' : 'Booster ${p.roleOrder}'} (menggeser ${p.pumpCn})',
    ));
  }
  final maxRole = target.pumps.isEmpty
      ? -1
      : target.pumps.map((p) => p.roleOrder).reduce((a, b) => a > b ? a : b);
  opts.add((
    value: maxRole + 1,
    label:
        'Paling belakang — ${maxRole + 1 == 0 ? 'Primer' : 'Booster ${maxRole + 1}'}',
  ));
  return opts;
}

Widget _systemField(TextEditingController sistem) {
  return TextField(
    controller: sistem,
    decoration: InputDecoration(
      labelText: 'Sistem Pemompaan',
      hintText: 'cth SARABAKAWA',
      isDense: true,
      suffixIcon: PopupMenuButton<String>(
        icon: const Icon(Icons.arrow_drop_down),
        onSelected: (v) => sistem.text = v,
        itemBuilder: (c) => [
          for (final s in stagingSystems)
            PopupMenuItem(value: s, child: Text(s)),
        ],
      ),
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
