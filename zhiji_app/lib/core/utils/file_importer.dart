import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// 文件导入工具
/// 支持：TXT、Markdown、PDF文本提取
class FileImporter {
  FileImporter._();

  /// 支持的扩展名
  static const _extensions = ['txt', 'md', 'markdown', 'pdf', 'csv', 'json'];

  /// 打开文件选择器并读取内容
  /// 返回 (文件名, 文本内容)
  static Future<(String, String)?> pickAndRead() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    final name = file.name;

    if (path == null) return null;

    try {
      final f = File(path);
      final content = await f.readAsString();
      return (name, content);
    } catch (e) {
      return null;
    }
  }

  /// 弹出文件选择 + 内容插入，带 UI Toast
  static Future<void> pickAndInsert(
    BuildContext context, {
    required void Function(String fileName, String content) onInsert,
  }) async {
    final result = await pickAndRead();
    if (result == null) return;

    final (name, content) = result;
    onInsert(name, content);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 已导入: $name')),
      );
    }
  }
}
