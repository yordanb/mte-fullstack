import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart' show apiMessage;
import '../../../core/utils/date_fmt.dart';
import '../data/project_api.dart';
import '../domain/project_models.dart';
import 'project_providers.dart';

/// Dialog form project baru (web ProjectForm).
Future<void> showProjectForm(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final desc = TextEditingController();
  final pic = TextEditingController();
  final cn = TextEditingController();
  final crew = TextEditingController();
  var targetDate = '';

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: const Text('Project Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Nama project',
                    hintText: 'cth Overhaul Pompa WP855'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pic,
                      decoration: const InputDecoration(labelText: 'PIC'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateField(c, 'Target selesai', targetDate,
                        (v) => setSt(() => targetDate = v)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cn,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Unit / CN', hintText: 'cth WP855'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _crewField(c, crew),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              try {
                await ref.read(projectApiProvider).create({
                  'name': name.text.trim(),
                  'description':
                      desc.text.trim().isEmpty ? null : desc.text.trim(),
                  'pic': pic.text.trim().isEmpty ? null : pic.text.trim(),
                  'cn': cn.text.trim().isEmpty
                      ? null
                      : cn.text.trim().toUpperCase(),
                  'crew': crew.text.trim().isEmpty ? null : crew.text.trim(),
                  'target_date': targetDate.isEmpty ? null : targetDate,
                });
                ref.invalidate(projectListProvider);
                if (c.mounted) Navigator.pop(c);
              } catch (e) {
                if (c.mounted) _snack(c, apiMessage(e));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog form tahap baru (web StageForm).
Future<void> showStageForm(
    BuildContext context, WidgetRef ref, String pid) async {
  final name = TextEditingController();
  final weight = TextEditingController();
  var planStart = '';
  var planEnd = '';

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: const Text('Tahap Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Nama tahap', hintText: 'cth Pembongkaran'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _dateField(c, 'Rencana mulai', planStart,
                        (v) => setSt(() => planStart = v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateField(c, 'Rencana selesai', planEnd,
                        (v) => setSt(() => planEnd = v)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Bobot % (opsional)',
                    hintText: 'untuk agregat progress'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              try {
                await ref.read(projectApiProvider).addStage(pid, {
                  'name': name.text.trim(),
                  'plan_start': planStart.isEmpty ? null : planStart,
                  'plan_end': planEnd.isEmpty ? null : planEnd,
                  'weight': weight.text.trim().isEmpty
                      ? null
                      : num.tryParse(weight.text.trim()),
                });
                ref.invalidate(projectDetailProvider(pid));
                ref.invalidate(projectListProvider);
                if (c.mounted) Navigator.pop(c);
              } catch (e) {
                if (c.mounted) _snack(c, apiMessage(e));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog form update progress tahap + upload foto (web UpdateForm).
Future<void> showUpdateForm(
    BuildContext context, WidgetRef ref, String sid, String pid) async {
  var date = toApiDate(DateTime.now());
  final prog = TextEditingController(text: '0');
  var status = 'ON_TRACK';
  final note = TextEditingController();
  final pickedPaths = <String>[];
  final pickedNames = <String>[];
  var busy = false;
  var pct = 0;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: const Text('Update Progress Tahap'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dateField(c, 'Tanggal', date,
                        (v) => setSt(() => date = v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: prog,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Progress %', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in projUpdateStatuses)
                    DropdownMenuItem(
                        value: s, child: Text(projStatusLabel(s))),
                ],
                onChanged: (v) => setSt(() => status = v ?? status),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    hintText: 'progres hari ini, kendala, rencana besok...'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final res = await fp.FilePicker.pickFiles(
                                  type: fp.FileType.image, allowMultiple: true);
                              if (res == null) return;
                              setSt(() {
                                for (final f in res.files) {
                                  if (f.path != null) {
                                    pickedPaths.add(f.path!);
                                    pickedNames.add(f.name);
                                  }
                                }
                              });
                            },
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: Text('Foto eviden (${pickedPaths.length})',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              if (busy)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Mengunggah... $pct%',
                      style: const TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final p = int.tryParse(prog.text.trim()) ?? 0;
                    setSt(() {
                      busy = true;
                      pct = 0;
                    });
                    try {
                      await ref.read(projectApiProvider).addUpdate(
                            sid,
                            date: date,
                            progress: p,
                            status: status,
                            note: note.text.trim().isEmpty
                                ? null
                                : note.text.trim(),
                            paths: pickedPaths,
                            names: pickedNames,
                            onProgress: (sent, total) {
                              if (total > 0) {
                                setSt(() => pct = (sent * 100 ~/ total));
                              }
                            },
                          );
                      ref.invalidate(projectDetailProvider(pid));
                      ref.invalidate(projectListProvider);
                      if (c.mounted) Navigator.pop(c);
                    } catch (e) {
                      if (c.mounted) {
                        setSt(() => busy = false);
                        _snack(c, apiMessage(e));
                      }
                    }
                  },
            child: Text(busy ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    ),
  );
}

Widget _crewField(BuildContext context, TextEditingController crew) {
  return TextField(
    controller: crew,
    decoration: InputDecoration(
      labelText: 'Crew',
      hintText: 'pilih / ketik',
      suffixIcon: PopupMenuButton<String>(
        icon: const Icon(Icons.arrow_drop_down),
        onSelected: (v) => crew.text = v,
        itemBuilder: (c) => [
          for (final cw in projCrews)
            PopupMenuItem(value: cw, child: Text(cw)),
        ],
      ),
    ),
  );
}

Widget _dateField(BuildContext context, String label, String value,
    void Function(String) onChanged,
    {bool allowClear = false}) {
  return InkWell(
    onTap: () async {
      final init = DateTime.tryParse(value) ?? DateTime.now();
      final p = await showDatePicker(
        context: context,
        initialDate: init,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (p != null) onChanged(toApiDate(p));
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: allowClear && value.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(''),
              )
            : const Icon(Icons.calendar_today, size: 16),
      ),
      child: Text(value.isEmpty ? '—' : value,
          style: const TextStyle(fontSize: 12.5)),
    ),
  );
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
