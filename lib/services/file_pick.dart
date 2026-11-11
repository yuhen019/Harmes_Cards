import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// 选错了文件类型
class FilePickError implements Exception {
  final String message;
  const FilePickError(this.message);

  @override
  String toString() => message;
}

/// 选择本地文件
///
/// 桌面端可以按扩展名过滤；Android 上扩展名过滤依赖系统文件管理器的 MIME 匹配，
/// `md` / `markdown` / `json` 这类后缀经常直接被藏起来，用户根本选不到。
/// 所以移动端一律放开（FileType.any），选完再按后缀校验。
class FilePick {
  static Future<PlatformFile?> pick({
    required List<String> extensions,
    String? dialogTitle,
  }) async {
    final mobile = Platform.isAndroid || Platform.isIOS;
    final result = await FilePicker.platform.pickFiles(
      type: mobile ? FileType.any : FileType.custom,
      allowedExtensions: mobile ? null : extensions,
      withData: true,
      dialogTitle: dialogTitle,
    );
    if (result == null || result.files.isEmpty) return null; // 用户取消

    final file = result.files.single;
    if (!mobile) return file;

    final ext = (file.extension ?? '').toLowerCase();
    if (ext.isEmpty || !extensions.contains(ext)) {
      throw FilePickError('这不是支持的文件（需要 .${extensions.join(' / .')}）');
    }
    return file;
  }
}
