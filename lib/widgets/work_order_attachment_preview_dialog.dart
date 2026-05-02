import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/work_order.dart';
import '../theme/navalgo_theme.dart';
import '../utils/app_toast.dart';
import '../utils/browser_file_download.dart';
import '../utils/media_url.dart';

Future<void> showWorkOrderAttachmentPreviewDialog({
  required BuildContext context,
  required WorkOrderAttachmentItem attachment,
  String? authToken,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _WorkOrderAttachmentPreviewDialog(
      attachment: attachment,
      authToken: authToken,
    ),
  );
}

class _WorkOrderAttachmentPreviewDialog extends StatefulWidget {
  const _WorkOrderAttachmentPreviewDialog({
    required this.attachment,
    required this.authToken,
  });

  final WorkOrderAttachmentItem attachment;
  final String? authToken;

  @override
  State<_WorkOrderAttachmentPreviewDialog> createState() =>
      _WorkOrderAttachmentPreviewDialogState();
}

class _WorkOrderAttachmentPreviewDialogState
    extends State<_WorkOrderAttachmentPreviewDialog> {
  late final Future<void> _loadFuture = _loadPreview();

  Uint8List? _previewBytes;
  String? _contentType;
  String? _webVideoObjectUrl;
  VideoPlayerController? _videoController;
  bool _isDownloading = false;

  bool get _isVideo => widget.attachment.fileType == 'VIDEO';

  String get _fileName {
    final raw = widget.attachment.originalFileName?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return _isVideo ? 'adjunto-video.mp4' : 'adjunto-imagen.jpg';
  }

  String get _resolvedUrl {
    final resolvedUrl = resolveMediaUrl(widget.attachment.fileUrl);
    return resolvedUrl.isEmpty ? widget.attachment.fileUrl : resolvedUrl;
  }

  @override
  void dispose() {
    _videoController?.dispose();
    revokeObjectUrl(_webVideoObjectUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = _buildAttachmentDetails(widget.attachment);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: MediaQuery.of(context).size.height * 0.84,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: NavalgoColors.mist,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isVideo
                          ? Icons.videocam_outlined
                          : Icons.photo_camera_back_outlined,
                      color: NavalgoColors.tide,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge,
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: double.infinity,
                    color: _isVideo ? Colors.black : NavalgoColors.shell,
                    child: FutureBuilder<void>(
                      future: _loadFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return _AttachmentErrorState(
                            message: 'No se pudo cargar el adjunto.',
                            onOpenSecondary: _secondaryAction,
                            secondaryLabel: kIsWeb ? 'Descargar' : 'Abrir fuera',
                          );
                        }

                        return _isVideo
                            ? _buildVideoPreview()
                            : _buildImagePreview();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _secondaryAction,
                    icon: Icon(
                      kIsWeb
                          ? Icons.download_outlined
                          : Icons.open_in_new_outlined,
                    ),
                    label: Text(kIsWeb ? 'Descargar' : 'Abrir fuera'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final bytes = _previewBytes;
    if (bytes == null || bytes.isEmpty) {
      return _AttachmentErrorState(
        message: 'No se pudo cargar la imagen.',
        onOpenSecondary: _secondaryAction,
        secondaryLabel: kIsWeb ? 'Descargar' : 'Abrir fuera',
      );
    }

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: Center(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio == 0
                ? 16 / 9
                : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.black.withValues(alpha: 0.62),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: _togglePlayback,
                  icon: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white.withValues(alpha: 0.36),
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatVideoPosition(controller.value.position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadPreview() async {
    if (_isVideo) {
      await _initializeVideoPreview();
      return;
    }

    final payload = await _downloadAttachmentBytes();
    _previewBytes = payload.bytes;
    _contentType = payload.contentType;
  }

  Future<void> _initializeVideoPreview() async {
    if (kIsWeb) {
      final payload = await _downloadAttachmentBytes();
      _previewBytes = payload.bytes;
      _contentType = payload.contentType;
      _webVideoObjectUrl = createObjectUrlFromBytes(
        payload.bytes,
        mimeType: payload.contentType ?? 'video/mp4',
      );
      if (_webVideoObjectUrl == null || _webVideoObjectUrl!.isEmpty) {
        throw Exception('No web object url available');
      }
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_webVideoObjectUrl!),
      );
    } else {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_resolvedUrl),
        httpHeaders: {
          ...?buildMediaHeaders(widget.authToken),
        },
      );
    }

    await _videoController!.initialize();
    await _videoController!.setLooping(false);
    _videoController!.addListener(_onVideoChanged);
  }

  void _onVideoChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<_BinaryPayload> _downloadAttachmentBytes() async {
    final response = await http.get(
      Uri.parse(_resolvedUrl),
      headers: {
        ...?buildMediaHeaders(widget.authToken),
      },
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Attachment request failed with ${response.statusCode}');
    }

    return _BinaryPayload(
      bytes: response.bodyBytes,
      contentType: response.headers['content-type']?.trim(),
    );
  }

  Future<void> _secondaryAction() async {
    if (kIsWeb) {
      await _downloadForWeb();
      return;
    }
    await _openOutsideApp();
  }

  Future<void> _downloadForWeb() async {
    setState(() => _isDownloading = true);
    try {
      final payload = _previewBytes != null
          ? _BinaryPayload(bytes: _previewBytes!, contentType: _contentType)
          : await _downloadAttachmentBytes();
      await downloadFileBytes(
        payload.bytes,
        fileName: _fileName,
        mimeType: payload.contentType ?? _fallbackMimeType(),
      );
      if (mounted) {
        AppToast.success(context, 'Archivo descargado.');
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'No se pudo descargar el archivo: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _openOutsideApp() async {
    final rawUrl = widget.attachment.fileUrl.trim();
    final targetUrl = rawUrl.isNotEmpty ? rawUrl : _resolvedUrl;
    final opened = await launchUrl(
      Uri.parse(targetUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      AppToast.error(context, 'No se pudo abrir el archivo.');
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  String _buildAttachmentDetails(WorkOrderAttachmentItem item) {
    final parts = <String>[];
    if (item.capturedAt != null) {
      parts.add('Captura: ${item.capturedAt!.toLocal()}');
    }
    if (item.latitude != null && item.longitude != null) {
      parts.add(
        'GPS: ${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
      );
    }
    if (item.watermarked) {
      parts.add('Con marca de agua');
    }
    return parts.join(' • ');
  }

  String _fallbackMimeType() {
    if (_isVideo) {
      return 'video/mp4';
    }

    final lowerFileName = _fileName.toLowerCase();
    if (lowerFileName.endsWith('.png')) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  String _formatVideoPosition(Duration position) {
    final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _BinaryPayload {
  const _BinaryPayload({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String? contentType;
}

class _AttachmentErrorState extends StatelessWidget {
  const _AttachmentErrorState({
    required this.message,
    required this.onOpenSecondary,
    required this.secondaryLabel,
  });

  final String message;
  final Future<void> Function() onOpenSecondary;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                size: 56,
                color: NavalgoColors.storm,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onOpenSecondary,
                icon: Icon(
                  kIsWeb
                      ? Icons.download_outlined
                      : Icons.open_in_new_outlined,
                ),
                label: Text(secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
