// 把导入模板导出到指定目录（默认当前目录）
// 用法：dart run tool/export_templates.dart <输出目录>
import 'dart:io';
import 'package:hermes_cards/services/template_service.dart';

Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args[0] : Directory.current.path;
  Directory.current = out;
  final t = TemplateService();
  stdout.writeln(await t.exportCsvTemplate());
  stdout.writeln(await t.exportMdTemplate());
}
