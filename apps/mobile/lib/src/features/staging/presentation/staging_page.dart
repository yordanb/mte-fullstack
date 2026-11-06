import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../../../core/utils/date_fmt.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../data/staging_api.dart';
import '../domain/staging_models.dart';
import 'staging_forms.dart';
import 'staging_providers.dart';

/// Staging Pump — paritas web Staging.tsx, versi sederhana:
/// tampilan kartu/tabel + pindah grup (tanpa drag-drop).
class StagingPage extends ConsumerStatefulWidget {
  const StagingPage({super.key});

  @override
  ConsumerState<StagingPage> createState() => _StagingPageState();
}

class _StagingPageState extends ConsumerState<StagingPage> {
  bool _tableView = false;
  bool _changesOpen = false;
  String _msg = '';

  void _reload() => ref.read(stagingTickProvider.notifier).bump();

  Future<void> _confirmDeleteGroup(StagingGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text('Hapus grup "${g.sumpClean.isEmpty ? 'No ${g.groupNo}' : g.sumpClean}" beserta pump-nya?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(stagingApiProvider).deleteGroup(g.id);
      _reload();
    } catch (e) {
      setState(() => _msg = 'gagal: ${apiMessage(e)}');
    }
  }

  Future<void> _deletePump(StagingPump p) async {
    try {
      await ref.read(stagingApiProvider).deletePump(p.id);
      _reload();
    } catch (e) {
      setState(() => _msg = 'gagal: ${apiMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(stagingPeriodProvider);
    final groupsAsync = ref.watch(stagingGroupsProvider);
    final auth = ref.watch(authProvider);
    final canEdit = auth.can('staging', 'edit');
    final groups = groupsAsync.maybeWhen(
        data: (v) => v, orElse: () => const <StagingGroup>[]);
    final hasData = groups.any((g) => g.pumps.isNotEmpty);

    return AppScaffold(
      title: 'Staging Pump',
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await ref.read(stagingGroupsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _toolbar(period, groups, canEdit, hasData),
            if (_msg.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_msg,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 12),
            groupsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(stagingGroupsProvider)),
              data: (gs) {
                if (gs.isEmpty) return _emptyState(canEdit, period);
                return _tableView
                    ? _table(gs)
                    : Column(
                        children: [
                          for (final g in gs)
                            _groupRow(g, period, groups, canEdit),
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            _changesPanel(period),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () =>
                  showAddGroupDialog(context, ref, period),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Grup'),
            )
          : null,
    );
  }

  Widget _toolbar(String period, List<StagingGroup> groups, bool canEdit,
      bool hasData) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => ref.read(stagingPeriodProvider.notifier).shift(-1),
          child: const Text('‹'),
        ),
        SizedBox(
          width: 140,
          child: Text(stagingPeriodLabel(period),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        OutlinedButton(
          onPressed: () => ref.read(stagingPeriodProvider.notifier).shift(1),
          child: const Text('›'),
        ),
        if (canEdit && !hasData)
          OutlinedButton(
            onPressed: () => showCopyDialog(context, ref, period),
            child: const Text('Copy dari bulan lain',
                style: TextStyle(fontSize: 11.5)),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _tableView = !_tableView),
          icon: Icon(_tableView ? Icons.grid_view : Icons.table_rows,
              size: 16),
          label: Text(_tableView ? 'Kartu' : 'Tabel',
              style: const TextStyle(fontSize: 11.5)),
        ),
        Text('${groups.length} grup',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _emptyState(bool canEdit, String period) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.settings_input_component,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Belum ada grup staging untuk ${stagingPeriodLabel(period)}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            if (canEdit) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => showCopyDialog(context, ref, period),
                    child: const Text('Copy dari bulan lain',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                  FilledButton(
                    onPressed: () => showAddGroupDialog(context, ref, period),
                    child: const Text('Tambah Grup',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _groupRow(StagingGroup g, String period, List<StagingGroup> groups,
      bool canEdit) {
    return Opacity(
      opacity: g.isActive ? 1 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade200,
                    child: Text('${g.groupNo}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.sumpClean.isEmpty ? '(tanpa sump)' : g.sumpClean,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        Text(g.systemType,
                            style: TextStyle(
                                fontSize: 10.5, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.settings, size: 18),
                      onSelected: (v) {
                        if (v == 'edit') {
                          showEditGroupDialog(context, ref, g);
                        } else if (v == 'del') {
                          _confirmDeleteGroup(g);
                        }
                      },
                      itemBuilder: (c) => const [
                        PopupMenuItem(value: 'edit', child: Text('Ubah')),
                        PopupMenuItem(
                            value: 'del',
                            child: Text('Hapus',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (g.pumps.isEmpty)
                Text('Belum ada pump',
                    style:
                        TextStyle(fontSize: 11.5, color: Colors.grey.shade400))
              else
                _pumpChain(g, groups, canEdit),
              if (canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showAddPumpDialog(g, period),
                    icon: const Icon(Icons.add, size: 16),
                    label:
                        const Text('Pump', style: TextStyle(fontSize: 11.5)),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 32)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pumpChain(
      StagingGroup g, List<StagingGroup> groups, bool canEdit) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: g.pumps.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
        ),
        itemBuilder: (c, i) {
          final p = g.pumps[i];
          final (border, bg, text) = stagingRoleColor(p.roleOrder);
          return _pumpCard(p, g, groups, canEdit, border, bg, text);
        },
      ),
    );
  }

  Widget _pumpCard(StagingPump p, StagingGroup g, List<StagingGroup> groups,
      bool canEdit, int border, int bg, int text) {
    return Container(
      width: 90,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Color(bg),
        border: Border.all(color: Color(border), width: 1.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(p.pumpCn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              if ((p.unitType ?? '').isNotEmpty)
                Text(p.unitType!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              Text(p.roleLabel,
                  style: TextStyle(
                      fontSize: 9.5,
                      color: Color(text),
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (canEdit)
            Positioned(
              right: -8,
              top: -12,
              child: Row(
                children: [
                  if (groups.where((x) => x.id != g.id && x.isActive).isNotEmpty)
                    _miniIcon(Icons.swap_horiz, Colors.blue,
                        () => showMovePumpDialog(context, ref, p, g.id, groups)),
                  const SizedBox(width: 2),
                  _miniIcon(Icons.close, Colors.red, () => _deletePump(p)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 11, color: Colors.white),
      ),
    );
  }

  Widget _table(List<StagingGroup> groups) {
    final canEdit = ref.watch(authProvider).can('staging', 'edit');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('No · Sump · Sistem · Urutan Pump',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            for (final g in groups)
              Opacity(
                opacity: g.isActive ? 1 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                              width: 28,
                              child: Text('${g.groupNo}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey))),
                          Expanded(
                            child: Text(
                              g.sumpClean.isEmpty ? '-' : g.sumpClean,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('${g.pumps.length} pump',
                              style: TextStyle(
                                  fontSize: 10.5, color: Colors.grey.shade500)),
                        ],
                      ),
                      Text(
                        g.systemType +
                            (g.isActive ? '' : '  •  non-aktif'),
                        style: TextStyle(
                            fontSize: 10.5,
                            color: g.isActive
                                ? Colors.grey.shade500
                                : Colors.grey.shade400),
                      ),
                      const SizedBox(height: 4),
                      if (g.pumps.isEmpty)
                        Text('—',
                            style: TextStyle(
                                fontSize: 11.5, color: Colors.grey.shade400))
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (var i = 0; i < g.pumps.length; i++) ...[
                              if (i > 0)
                                const Icon(Icons.arrow_forward,
                                    size: 12, color: Colors.grey),
                              _tableChip(g.pumps[i]),
                            ],
                          ],
                        ),
                      if (canEdit)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    showEditGroupDialog(context, ref, g),
                                child: const Text('Ubah',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              TextButton(
                                onPressed: () => _confirmDeleteGroup(g),
                                child: const Text('Hapus',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tableChip(StagingPump p) {
    final (_, _, text) = stagingRoleColor(p.roleOrder);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: Color(text), shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(p.pumpCn, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(' ${p.roleLabel}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _changesPanel(String period) {
    final changesAsync = ref.watch(stagingChangesProvider);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: Text('Riwayat Perubahan — ${stagingPeriodLabel(period)}',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
            trailing: Icon(_changesOpen
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down),
            onTap: () => setState(() => _changesOpen = !_changesOpen),
          ),
          if (_changesOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: changesAsync.when(
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator())),
                error: (e, _) => Text('$e',
                    style: const TextStyle(
                        fontSize: 11.5, color: Colors.red)),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Text('Belum ada perubahan pada periode ini.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500));
                  }
                  return Column(
                    children: [
                      for (final c in rows) _changeRow(c),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _changeRow(StagingChange c) {
    final (label, bg, fg) = _changeStyle(c.changeType);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(
                  style: const TextStyle(fontSize: 11.5),
                  children: [
                    if ((c.pumpCn ?? '').isNotEmpty)
                      TextSpan(
                          text: '${c.pumpCn} ',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    if ((c.fromValue ?? '').isNotEmpty)
                      TextSpan(
                          text: c.fromValue,
                          style: TextStyle(color: Colors.grey.shade600)),
                    if ((c.fromValue ?? '').isNotEmpty &&
                        (c.toValue ?? '').isNotEmpty)
                      TextSpan(
                          text: ' → ',
                          style: TextStyle(color: Colors.grey.shade400)),
                    if ((c.toValue ?? '').isNotEmpty)
                      TextSpan(text: c.toValue),
                    if ((c.fromValue ?? '').isEmpty &&
                        (c.toValue ?? '').isEmpty)
                      TextSpan(
                          text: c.sumpName ?? c.systemType ?? '',
                          style: TextStyle(color: Colors.grey.shade500)),
                    TextSpan(
                        text: '  • Grup ${c.groupNo}',
                        style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                )),
                Text('${fmtDT(c.changedAt)} • ${c.changedBy}',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, Color) _changeStyle(String t) {
    switch (t) {
      case 'ADD_PUMP':
        return ('Tambah', const Color(0xFFECFDF5), const Color(0xFF059669));
      case 'REMOVE_PUMP':
        return ('Hapus', const Color(0xFFFEF2F2), const Color(0xFFDC2626));
      case 'REORDER':
        return ('Urutan', const Color(0xFFEFF6FF), const Color(0xFF2563EB));
      case 'GROUP_EDIT':
        return ('Grup', const Color(0xFFFFFBEB), const Color(0xFFD97706));
      case 'MOVE':
        return ('Pindah', const Color(0xFFF5F3FF), const Color(0xFF7C3AED));
      default:
        return (t, const Color(0xFFF3F4F6), const Color(0xFF4B5563));
    }
  }

  Future<void> _showAddPumpDialog(StagingGroup g, String period) async {
    final chain = TextEditingController();
    var busy = false;
    var msg = '';

    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) {
          final cns = stagingParseChain(chain.text);
          return AlertDialog(
            title: Text('Tambah pump — ${g.sumpClean.isEmpty ? 'Grup ${g.groupNo}' : g.sumpClean}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: chain,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Pump berurutan (Primer → Booster)',
                      hintText: 'WP676 - WP498 - WP471 - WP821',
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
                                '${cns[i]} (${stagingRoleLabel(i)})',
                                style: const TextStyle(fontSize: 10.5),
                              ),
                            ),
                        ],
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
                        if (cns.isEmpty) return;
                        setSt(() {
                          busy = true;
                          msg = '';
                        });
                        final api = ref.read(stagingApiProvider);
                        for (var i = 0; i < cns.length; i++) {
                          try {
                            await api.addPump(g.id,
                                pumpCn: cns[i],
                                roleOrder: g.pumps.length + i,
                                period: period);
                          } catch (e) {
                            setSt(() {
                              busy = false;
                              msg = 'Gagal: ${cns[i]} — ${apiMessage(e)}';
                            });
                            _reload();
                            return;
                          }
                        }
                        _reload();
                        if (c.mounted) Navigator.pop(c);
                      },
                child: Text(busy ? 'Menambah...' : 'Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }
}
