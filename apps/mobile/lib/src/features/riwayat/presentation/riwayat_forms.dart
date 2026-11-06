import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart' show apiMessage;
import '../../../core/utils/date_fmt.dart';
import '../data/riwayat_api.dart';
import '../domain/riwayat_models.dart';
import 'riwayat_providers.dart';

/// Dialog form issue (baru/ubah) — paritas web IssueForm.
Future<void> showIssueForm(BuildContext context, WidgetRef ref,
    {RiwayatIssue? issue}) async {
  final title = TextEditingController(text: issue?.title ?? '');
  final cn = TextEditingController(text: issue?.cn ?? '');
  final desc = TextEditingController(text: issue?.description ?? '');
  var category = issue?.category ?? riwayatCats.first;
  var status = issue?.status ?? 'open';
  var startDate = issue?.startDate.isNotEmpty == true
      ? issue!.startDate
      : toApiDate(DateTime.now());
  var endDate = issue?.endDate ?? '';

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: Text(issue == null ? 'Issue Baru' : 'Ubah Issue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                    labelText: 'Judul Issue',
                    hintText: 'cth Breakdown Unscheduled WP1190'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cn,
                      decoration: const InputDecoration(
                          labelText: 'Unit (CN)', hintText: 'cth WP1190'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: [
                  for (final c2 in riwayatCats)
                    DropdownMenuItem(value: c2, child: Text(c2)),
                ],
                onChanged: (v) => setSt(() => category = v ?? category),
              ),
              const SizedBox(height: 8),
              _dateField(c, 'Start Date', startDate,
                  (v) => setSt(() => startDate = v)),
              const SizedBox(height: 8),
              _dateField(
                c,
                'End Date (opsional)',
                endDate,
                (v) => setSt(() => endDate = v),
                allowClear: true,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in riwayatStatuses)
                    DropdownMenuItem(value: s.value, child: Text(s.label)),
                ],
                onChanged: (v) => setSt(() => status = v ?? status),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: desc,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Deskripsi', hintText: 'Detail issue...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              final payload = {
                'title': title.text.trim(),
                'cn': cn.text.trim().isEmpty ? null : cn.text.trim(),
                'category': category,
                'status': status,
                'start_date': startDate,
                'end_date': endDate.isEmpty ? null : endDate,
                'description': desc.text.trim().isEmpty ? null : desc.text.trim(),
              };
              try {
                final api = ref.read(riwayatApiProvider);
                if (issue == null) {
                  await api.createIssue(payload);
                } else {
                  await api.patchIssue(issue.id, payload);
                  ref.invalidate(riwayatIssueProvider(issue.id));
                }
                ref.invalidate(riwayatIssuesProvider);
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

/// Dialog form progress (baru/ubah).
Future<void> showProgressForm(BuildContext context, WidgetRef ref, int issueId,
    {RiwayatProgress? progress}) async {
  final desc = TextEditingController(text: progress?.description ?? '');
  var logDate = progress?.logDate.isNotEmpty == true
      ? progress!.logDate.substring(0, 10)
      : toApiDate(DateTime.now());
  var partReq = progress?.partRequired ?? false;

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: Text(progress == null ? 'Progress Baru' : 'Edit Progress'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dateField(c, 'Tanggal Progress', logDate,
                  (v) => setSt(() => logDate = v)),
              const SizedBox(height: 8),
              TextField(
                controller: desc,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    hintText: 'cth: Sudah dibongkar, ditemukan bearing aus'),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: partReq,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Membutuhkan part (requirement part)',
                    style: TextStyle(fontSize: 12)),
                onChanged: (v) => setSt(() => partReq = v ?? false),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (desc.text.trim().isEmpty) return;
              final payload = {
                'description': desc.text.trim(),
                'part_required': partReq,
                'log_date': logDate,
              };
              try {
                final api = ref.read(riwayatApiProvider);
                if (progress == null) {
                  await api.addProgress(issueId, payload);
                } else {
                  await api.patchProgress(progress.id, payload);
                }
                ref.invalidate(riwayatIssueProvider(issueId));
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

/// Dialog form part (baru/ubah). `issueId` untuk part per-issue,
/// `progressId` untuk part per-progress (part request).
Future<void> showPartForm(BuildContext context, WidgetRef ref,
    {int? issueId, int? progressId, RiwayatPart? part}) async {
  final name = TextEditingController(text: part?.partName ?? '');
  final notes = TextEditingController(text: part?.notes ?? '');
  final qty = TextEditingController(text: '${part?.qty ?? 1}');
  var status = part?.status ?? 'needed';
  var eta = part?.eta?.substring(0, 10) ?? '';

  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: Text(part == null ? 'Part Baru' : 'Ubah Part'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Nama Part', hintText: 'cth Bearing NU210'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s in riwayatPartStatuses)
                          DropdownMenuItem(
                              value: s.value, child: Text(s.label)),
                      ],
                      onChanged: (v) => setSt(() => status = v ?? status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _dateField(c, 'ETA', eta, (v) => setSt(() => eta = v),
                  allowClear: true),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                decoration: const InputDecoration(
                    labelText: 'Notes', hintText: 'Catatan tambahan...'),
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
              final payload = {
                'part_name': name.text.trim(),
                'qty': int.tryParse(qty.text) ?? 1,
                'status': status,
                'eta': eta.isEmpty ? null : eta,
                'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
              };
              try {
                final api = ref.read(riwayatApiProvider);
                if (part != null) {
                  await api.patchPart(part.id, payload);
                } else if (progressId != null) {
                  await api.addPartToProgress(progressId, payload);
                } else if (issueId != null) {
                  await api.addPart(issueId, payload);
                }
                if (issueId != null) ref.invalidate(riwayatIssueProvider(issueId));
                if (progressId != null) {
                  ref.invalidate(riwayatPartsByProgressProvider(progressId));
                }
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
