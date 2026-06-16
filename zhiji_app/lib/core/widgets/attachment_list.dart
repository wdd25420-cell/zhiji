import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../theme/dimensions.dart';
import '../utils/file_attachment_manager.dart';

/// 附件列表组件
class AttachmentList extends StatelessWidget {
  const AttachmentList({
    super.key,
    required this.files,
    this.editable = false,
    this.onRemove,
  });

  final List<AttachedFile> files;
  final bool editable;
  final void Function(int index)? onRemove;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: List.generate(files.length, (i) {
        final file = files[i];
        return SizedBox(
          width: 140,
          child: Card(
            color: cs.surfaceContainerHighest,
            child: InkWell(
              onTap: () => _openFile(file),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        _buildThumbnail(file, cs),
                        if (editable)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: () => onRemove?.call(i),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: cs.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      file.sizeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildThumbnail(AttachedFile file, ColorScheme cs) {
    if (file.isImage) {
      return FutureBuilder<String>(
        future: FileAttachmentManager.getFullPath(file.storedPath),
        builder: (ctx, snap) {
          final path = snap.data;
          if (path != null && File(path).existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: Image.file(
                File(path),
                width: 120,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _fileIcon(file, cs, size: 48),
              ),
            );
          }
          return _fileIcon(file, cs, size: 48);
        },
      );
    }
    return _fileIcon(file, cs, size: 48);
  }

  Widget _fileIcon(AttachedFile file, ColorScheme cs, {double size = 48}) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForFile(file), size: size * 0.6, color: cs.primary),
            const SizedBox(height: 2),
            Text(
              file.extension.replaceFirst('.', '').toUpperCase(),
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForFile(AttachedFile file) {
    final ext = file.extension;
    if (ext == '.pdf') return Icons.picture_as_pdf;
    if (ext == '.doc' || ext == '.docx') return Icons.description;
    if (ext == '.xls' || ext == '.xlsx') return Icons.table_chart;
    if (ext == '.ppt' || ext == '.pptx') return Icons.slideshow;
    if (ext == '.txt' || ext == '.md' || ext == '.csv' || ext == '.json') return Icons.article;
    if (ext == '.mp3' || ext == '.wav' || ext == '.aac') return Icons.audio_file;
    if (ext == '.mp4') return Icons.video_file;
    if (ext == '.zip' || ext == '.rar' || ext == '.7z') return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Future<void> _openFile(AttachedFile file) async {
    try {
      final path = await FileAttachmentManager.getFullPath(file.storedPath);
      await OpenFilex.open(path, type: file.mimeType);
    } catch (e) {
      debugPrint('打开文件失败: $e');
    }
  }
}
