import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../data/riwayat_api.dart';
import '../domain/riwayat_models.dart';

/// Galeri foto/file evidence (progress & part) — paritas web PhotoGallery:
/// grid thumbnail, tambah foto, hapus, keterangan (notes), pratinjau.
/// `kind` menentukan endpoint & URL: 'progress' atau 'part'.
class RiwayatPhotoGallery extends ConsumerStatefulWidget {
  final String kind;
  final int itemId;
  final Future<List<RiwayatPhoto>> Function() load;
  final Future<void> Function(List<String> paths, List<String> names) upload;
  final Future<void> Function(int phid) delete;
  final Future<void> Function(int phid, String? notes) patchNotes;
  final void Function(String message)? onError;

  const RiwayatPhotoGallery({
    super.key,
    required this.kind,
    required this.itemId,
    required this.load,
    required this.upload,
    required this.delete,
    required this.patchNotes,
    this.onError,
  });

  @override
  ConsumerState<RiwayatPhotoGallery> createState() =>
      _RiwayatPhotoGalleryState();
}

class _RiwayatPhotoGalleryState extends ConsumerState<RiwayatPhotoGallery> {
  List<RiwayatPhoto> _photos = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final p = await widget.load();
      if (mounted) setState(() => _photos = p);
    } catch (_) {}
  }

  void _err(Object e) => widget.onError?.call(apiMessage(e));

  String _url(int phid, String token) => widget.kind == 'progress'
      ? RiwayatApi.progressPhotoUrl(widget.itemId, phid, token)
      : RiwayatApi.partPhotoUrl(widget.itemId, phid, token);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final token = ref.watch(accessTokenProvider).value ?? '';
    final canAdd = auth.can('riwayat', 'add');
    final canEdit = auth.can('riwayat', 'edit');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_photos.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ph in _photos)
                _thumb(ph, token, canEdit, canAdd),
            ],
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (canAdd)
              TextButton.icon(
                onPressed: _busy ? null : () => _pick(canEdit),
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('Foto/File', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            if (_busy)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ],
    );
  }

  Widget _thumb(RiwayatPhoto ph, String token, bool canEdit, bool canAdd) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: ph.isImage ? () => _preview(ph, token) : null,
                child: ph.isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _url(ph.id, token),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fileBox(ph),
                        ),
                      )
                    : _fileBox(ph),
              ),
              if (canEdit || canAdd)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Column(
                    children: [
                      if (canEdit)
                        _miniBtn(Icons.edit, Colors.blue, () => _editNotes(ph)),
                      if (canAdd)
                        _miniBtn(
                            Icons.close, Colors.red, () => _delete(ph)),
                    ],
                  ),
                ),
            ],
          ),
          if ((ph.notes ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(ph.notes!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }

  Widget _fileBox(RiwayatPhoto ph) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.grey.shade400),
            Text(ph.origName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8.5)),
          ],
        ),
      );

  Widget _miniBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 11, color: Colors.white),
        ),
      );

  Future<void> _pick(bool canEditNotes) async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.upload(
          files.map((f) => f.path).toList(), files.map((f) => f.name).toList());
      await _reload();
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RiwayatPhoto ph) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: const Text('Hapus foto ini?'),
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
      await widget.delete(ph.id);
      await _reload();
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _editNotes(RiwayatPhoto ph) async {
    final ctl = TextEditingController(text: ph.notes ?? '');
    final res = await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keterangan'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Keterangan...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (res == null) return;
    try {
      await widget.patchNotes(ph.id, res.isEmpty ? null : res);
      await _reload();
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _preview(RiwayatPhoto ph, String token) async {
    await showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                ph.origName +
                    ((ph.notes ?? '').isNotEmpty ? ' — ${ph.notes}' : ''),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Flexible(
              child: Image.network(_url(ph.id, token), fit: BoxFit.contain),
            ),
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Tutup')),
          ],
        ),
      ),
    );
  }
}
