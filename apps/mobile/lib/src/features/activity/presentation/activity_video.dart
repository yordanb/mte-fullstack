import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Pemutar video jaringan (auth lewat `?token=`) untuk review langsung di
/// aplikasi — meniru lightbox video web (Pages.tsx ActDetail).
///
/// Dipakai di dua mode:
///  - thumbnail: [VideoThumb] (muted, tanpa kontrol, ikon play overlay);
///  - penuh: dialog [showVideoDialog] dengan kontrol play/pause/seek + hapus opsional.
class VideoThumb extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;

  const VideoThumb({
    super.key,
    required this.url,
    this.width = 120,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      await c.setVolume(0); // thumbnail tanpa suara
      await c.setLooping(false);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _ctrl = c;
        _ready = true;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = !_ready || _ctrl == null
        ? Container(
            width: widget.width,
            height: widget.height,
            color: Colors.black87,
            child: const Center(
              child: Icon(Icons.movie, color: Colors.white54),
            ),
          )
        : SizedBox(
            width: widget.width,
            height: widget.height,
            child: FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _ctrl!.value.size.width,
                height: _ctrl!.value.size.height,
                child: VideoPlayer(_ctrl!),
              ),
            ),
          );
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          const Positioned.fill(
            child: Center(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog pemutar video penuh. [onDelete] opsional (gated izin hapus).
Future<void> showVideoDialog(
  BuildContext context, {
  required String url,
  String? title,
  Future<void> Function()? onDelete,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => VideoDialog(url: url, title: title, onDelete: onDelete),
  );
}

class VideoDialog extends StatefulWidget {
  final String url;
  final String? title;
  final Future<void> Function()? onDelete;

  const VideoDialog({super.key, required this.url, this.title, this.onDelete});

  @override
  State<VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<VideoDialog> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl = c;
    try {
      await c.initialize();
      await c.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _err = 'Gagal memutar video: $e');
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((widget.title ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline, color: Colors.white70),
                      onPressed: () async {
                        await widget.onDelete!();
                      },
                    ),
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_err!,
                  style: const TextStyle(color: Colors.redAccent)),
            )
          else if (!_ready || _ctrl == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else
            AspectRatio(
              aspectRatio: _ctrl!.value.aspectRatio == 0
                  ? 16 / 9
                  : _ctrl!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_ctrl!),
                  VideoProgressIndicator(
                    _ctrl!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: IconButton(
                      icon: Icon(
                        _ctrl!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: () {
                        setState(() {
                          _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
