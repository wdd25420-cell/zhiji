import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// 附件文件元数据
class AttachedFile {
  final String name;
  final String storedPath; // app 内部相对路径
  final int sizeBytes;
  final String mimeType;

  const AttachedFile({
    required this.name,
    required this.storedPath,
    required this.sizeBytes,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'storedPath': storedPath,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
      };

  factory AttachedFile.fromJson(Map<String, dynamic> json) => AttachedFile(
        name: json['name'] as String? ?? '',
        storedPath: json['storedPath'] as String? ?? '',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        mimeType: json['mimeType'] as String? ?? '',
      );

  /// 是否为图片
  bool get isImage => mimeType.startsWith('image/');

  /// 文件大小友好显示
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 文件名后缀
  String get extension => p.extension(name).toLowerCase();
}

/// 文件附件管理器
class FileAttachmentManager {
  FileAttachmentManager._();

  static Directory? _attachmentsDir;

  /// 附件存储目录
  static Future<Directory> get attachmentsDir async {
    if (_attachmentsDir != null) return _attachmentsDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _attachmentsDir = dir;
    return dir;
  }

  /// 获取附件的完整系统路径
  static Future<String> getFullPath(String storedPath) async {
    final dir = await attachmentsDir;
    return p.join(dir.path, storedPath);
  }

  /// 从系统文件选择器中选择文件（图片 + 文档）
  static Future<List<AttachedFile>> pickDocuments({bool allowMultiple = true}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'txt', 'md', 'csv', 'json',
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
        'mp3', 'mp4', 'wav', 'aac',
        'zip', 'rar', '7z',
      ],
    );
    if (result == null || result.files.isEmpty) return [];
    return _savePickedFiles(result.files);
  }

  /// 从相册中选择图片
  static Future<List<AttachedFile>> pickImages({bool allowMultiple = true}) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(limit: allowMultiple ? 9 : 1);
    if (images.isEmpty) return [];
    final files = images
        .map((x) => PlatformFile(
              name: x.name,
              path: x.path,
              size: 0,
            ))
        .toList();
    return _savePickedFiles(files);
  }

  /// 拍照
  static Future<AttachedFile?> takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return null;
    final files = await _savePickedFiles([
      PlatformFile(name: photo.name, path: photo.path, size: 0),
    ]);
    return files.isNotEmpty ? files.first : null;
  }

  // ============================================================
  // 权限引导
  // ============================================================

  /// 确保相机权限已授予，拒绝时弹出引导弹窗
  static Future<bool> ensureCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) {
      if (context.mounted) _showPermissionDeniedDialog(context, '相机');
      return false;
    }
    final result = await Permission.camera.request();
    if (!result.isGranted) {
      if (result.isPermanentlyDenied && context.mounted) {
        _showPermissionDeniedDialog(context, '相机');
      }
      return false;
    }
    return true;
  }

  /// 确保存储权限已授予（相册选择需要），拒绝时弹出引导弹窗
  static Future<bool> ensureGalleryPermission(BuildContext context) async {
    final status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) {
      if (context.mounted) _showPermissionDeniedDialog(context, '相册');
      return false;
    }
    final result = await Permission.photos.request();
    if (!result.isGranted) {
      if (result.isPermanentlyDenied && context.mounted) {
        _showPermissionDeniedDialog(context, '相册');
      }
      return false;
    }
    return true;
  }

  static void _showPermissionDeniedDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('需要$feature权限'),
        content: Text('知记需要$feature权限才能使用此功能。请在系统设置中授予权限。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  /// 保存选中的文件到附件目录
  static Future<List<AttachedFile>> _savePickedFiles(List<PlatformFile> files) async {
    final dir = await attachmentsDir;
    final attached = <AttachedFile>[];
    for (final pf in files) {
      if (pf.path == null) continue;
      final src = File(pf.path!);
      // 生成唯一文件名（加时间戳防冲突）
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final ext = p.extension(pf.name);
      final baseName = p.basenameWithoutExtension(pf.name);
      final safeName = '${baseName}_$timestamp$ext';
      final destPath = p.join(dir.path, safeName);
      try {
        await src.copy(destPath);
        final size = pf.size != 0 ? pf.size : await File(destPath).length();
        attached.add(AttachedFile(
          name: pf.name,
          storedPath: safeName,
          sizeBytes: size,
          mimeType: _mimeFromExtension(ext),
        ));
      } catch (e) {
        debugPrint('附件保存失败: $e');
      }
    }
    return attached;
  }

  /// 删除附件
  static Future<void> deleteFile(AttachedFile file) async {
    try {
      final fullPath = await getFullPath(file.storedPath);
      final f = File(fullPath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('附件删除失败: $e');
    }
  }

  /// 批量删除附件
  static Future<void> deleteFiles(List<AttachedFile> files) async {
    for (final f in files) {
      await deleteFile(f);
    }
  }

  /// JSON 编码
  static String? encode(List<AttachedFile> files) {
    if (files.isEmpty) return null;
    return jsonEncode(files.map((f) => f.toJson()).toList());
  }

  /// JSON 解码
  static List<AttachedFile> decode(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => AttachedFile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 根据扩展名推断 MIME 类型
  static String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.txt':
      case '.md':
        return 'text/plain';
      case '.csv':
        return 'text/csv';
      case '.json':
        return 'application/json';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
