import 'dart:convert';
import 'dart:io';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:path/path.dart' as p;
import '../models/card_item.dart';
import 'database_service.dart';

/// 导入模板服务
///
/// 提供两类模板下载：
///  1. CSV 模板 —— 带表头 + 示例行，填完即可导入
///  2. MD 规格文档 —— 一份完整的「卡片导入规格」，可直接丢给 AI 助手阅读，
///     让它按规格产出能直接导入的卡片文件（含写作铁律，避免 AI 生成一堆废卡）
class TemplateService {
  final DatabaseService _db = DatabaseService.instance;

  /// CSV 表头（顺序固定，导入时按名字匹配，顺序可换）
  static const List<String> csvFields = [
    'front',
    'back',
    'context',
    'source',
    'tag',
    'type',
    'flipped',
  ];

  static const String _csvTemplate = '''front,back,context,source,tag,type,flipped
"\u653e\u5f03\u3001\u629b\u5f03\uff08\u6b63\u5f0f\u7528\u8bed\uff09","abandon","They had to ___ the car in the snow and walk home.","\u96c5\u601d\u6838\u5fc3\u8bcd\u8868 List 3","\u5199\u4f5c\u9ad8\u9891","basic","0"
"\u53ef\u6301\u7eed\u7684","sustainable","___ development meets present needs without compromising the future.","\u96c5\u601d\u6838\u5fc3\u8bcd\u8868 List 3","\u5199\u4f5c\u9ad8\u9891","basic","0"
"\u4eba\u4f53\u9762\u79ef\u6700\u5927\u7684\u5668\u5b98","\u76ae\u80a4","\u6210\u4eba\u4f53\u8868\u9762\u79ef\u7ea6 1.5\u20132 \u5e73\u65b9\u7c73\uff0c\u662f\u6700\u5927\u5668\u5b98\u3002","\u7cfb\u7edf\u89e3\u5256\u5b66 \u7b2c 4 \u7ae0","\u671f\u672b\u91cd\u70b9","basic","0"
"\u6211\u60f3\u9884\u8ba2\u4e00\u5f20\u4e24\u4eba\u684c","Quisiera reservar una mesa para dos.","\u9910\u5385 \u00b7 \u9884\u8ba2","\u897f\u8bed\u751f\u5b58\u53e5 \u7b2c 1 \u8bfe","\u53e3\u8bed","speaking","0"
''';

  static const String _mdTemplate = '''# Hermes Cards \u5361\u7247\u5bfc\u5165\u89c4\u683c

> \u628a\u8fd9\u4efd\u6587\u6863\u4ea4\u7ed9 AI \u52a9\u624b\u9605\u8bfb\uff0c\u8ba9\u5b83\u6309\u89c4\u683c\u4ea7\u51fa\u53ef\u76f4\u63a5\u5bfc\u5165 Hermes Cards \u7684\u5361\u7247\u6587\u4ef6\u3002
> \u5bf9\u5e94\u7248\u672c\uff1aHermes Cards v1.2

---

## \u4e00\u3001\u8f93\u51fa\u683c\u5f0f

\u8bf7\u8f93\u51fa\u4e00\u4e2a CSV \u6587\u4ef6\uff0c\u7b2c\u4e00\u884c\u4e3a\u8868\u5934\uff0c\u5b57\u6bb5\u987a\u5e8f\u56fa\u5b9a\uff1a

```
front,back,context,source,tag,type,flipped
```

\u5b57\u6bb5\u542b\u9017\u53f7\u6216\u6362\u884c\u65f6\uff0c\u8bf7\u7528\u53cc\u5f15\u53f7\u5305\u88f9\uff08\u5982 `"a, b"`\uff09\u3002

---

## \u4e8c\u3001\u5b57\u6bb5\u8bf4\u660e

| \u5b57\u6bb5 | \u5fc5\u586b | \u8bf4\u660e |
|------|:---:|------|
| `front` | \u2705 | \u5361\u7247\u6b63\u9762\u2014\u2014\u5b66\u4e60\u8005**\u770b\u5230**\u7684\u5185\u5bb9\uff08\u95ee\u9898 / \u63d0\u793a\uff09 |
| `back` | \u2705 | \u5361\u7247\u53cd\u9762\u2014\u2014\u5b66\u4e60\u8005\u9700\u8981**\u4e3b\u52a8\u56de\u5fc6**\u51fa\u6765\u7684\u5185\u5bb9\uff08\u7b54\u6848\uff09 |
| `context` | \u5efa\u8bae | \u8bed\u5883\uff1a\u539f\u6587\u4f8b\u53e5 / \u51fa\u5904\u539f\u53e5 / \u4e0a\u4e0b\u6587\u3002\u5b64\u7acb\u77e5\u8bc6\u70b9\u8c03\u4e0d\u51fa\u6765\uff0c\u8fd9\u662f\u201c\u8ba4\u5f97\u4f46\u8bf4\u4e0d\u51fa\u201d\u7684\u89e3\u836f |
| `source` | \u9009\u586b | \u6765\u6e90\uff1a\u6587\u6863\u540d\u3001\u7ae0\u8282\u3001\u96c6\u6570\u3001\u65f6\u95f4\u6233 |
| `tag` | \u9009\u586b | \u6807\u7b7e\uff0c\u7528\u4e8e\u7b5b\u9009\u4e0e\u5206\u7ec4 |
| `type` | \u9009\u586b | `basic`\uff08\u9ed8\u8ba4\u95ee\u7b54\uff09/ `cloze`\uff08\u586b\u7a7a\uff09/ `speaking`\uff08\u5f00\u53e3\u5361\uff0c\u9700\u8bf4\u51fa\u6216\u5f55\u97f3\uff09 |
| `flipped` | \u9009\u586b | `0`\uff08\u9ed8\u8ba4\uff0cfront \u63d0\u95ee\uff09/ `1`\uff08\u7ffb\u8f6c\uff0c\u7528 back \u63d0\u95ee\uff09 |

---

## \u4e09\u3001\u5361\u7247\u5199\u4f5c\u94c1\u5f8b\uff08\u8fdd\u53cd\u4f1a\u5bfc\u81f4\u5b66\u4e60\u6548\u679c\u5d29\u584c\uff09

1. **\u4e00\u5361\u4e00\u4e49**\uff1a\u4e00\u5f20\u5361\u53ea\u8003\u4e00\u4e2a\u77e5\u8bc6\u70b9\u3002\u540c\u65f6\u8003\u4e24\u4e2a\u70b9\u7684\u5361\uff0c\u590d\u4e60\u65f6\u4f1a\u53d8\u6210\u201c\u534a\u4f1a\u534a\u4e0d\u4f1a\u201d\u3002
2. **\u7b54\u6848 \u2264 9 \u4e2a\u8bcd**\uff1a\u8d85\u8fc7 9 \u8bcd\u7684\u7b54\u6848\u56de\u5fc6\u6210\u529f\u7387\u65ad\u5d16\u4e0b\u964d\u3002\u957f\u5185\u5bb9\u62c6\u6210\u591a\u5f20\u3002
3. **\u5fc5\u987b\u5e26\u8bed\u5883**\uff08\u8bed\u8a00\u7c7b\u6750\u6599\uff09\uff1a\u53ea\u6709\u5b64\u7acb\u8bcd\u4e49\u7684\u5361\uff0c\u5b66\u4e60\u8005\u8ba4\u5f97\u5374\u8bf4\u4e0d\u51fa\u3002
4. **\u9ed8\u8ba4\u4e2d\u6587\u63d0\u95ee \u2192 \u5916\u8bed\u56de\u7b54**\uff08\u8bed\u8a00\u6750\u6599\uff09\uff1a\u53cd\u8fc7\u6765\u7ec3\u7684\u662f\u9605\u8bfb\u8ba4\u8bcd\uff0c\u5bf9\u5f00\u53e3\u5e2e\u52a9\u5f88\u5c0f\u3002
5. **\u4e0d\u8981\u751f\u6210\u9009\u62e9\u9898**\uff1a\u9009\u62e9\u9898\u6d4b\u7684\u662f\u201c\u518d\u8ba4\u201d\u800c\u975e\u201c\u56de\u5fc6\u201d\uff0c\u4e0e\u4e3b\u52a8\u56de\u5fc6\u539f\u5219\u51b2\u7a81\u3002
6. **\u6b63\u9762\u8981\u80fd\u72ec\u7acb\u6210\u7acb**\uff1a\u4e0d\u8981\u5199\u201c\u4e0a\u6587\u63d0\u5230\u7684\u90a3\u4e2a\u6982\u5ff5\u662f\u4ec0\u4e48\u201d\u8fd9\u7c7b\u4f9d\u8d56\u4e0a\u4e0b\u6587\u7684\u63d0\u95ee\u3002

---

## \u56db\u3001\u6570\u91cf\u63a7\u5236

- \u5355\u6b21\u751f\u6210\u5efa\u8bae **20\u201360 \u5f20**\u3002
- Hermes Cards \u9ed8\u8ba4\u6bcf\u6b21\u5bfc\u5165\u53ea\u542f\u7528\u524d 20 \u5f20\uff0c\u5176\u4f59\u5b58\u4e3a\u300c\u5f85\u542f\u7528\u300d\uff0c\u6bcf\u5929\u81ea\u52a8\u91ca\u653e\u4e00\u6279\u2014\u2014
  \u8fd9\u662f\u9632\u79ef\u538b\u62a4\u680f\uff0c**\u4e0d\u8981\u4e3a\u4e86\u201c\u4e00\u6b21\u7ed9\u5168\u201d\u800c\u8fc7\u91cf\u751f\u6210**\u3002\u7528\u6237\u7b2c\u4e09\u5929\u79ef\u538b\u7206\u70b8\u5c31\u4f1a\u653e\u5f03\u3002

---

## \u4e94\u3001\u793a\u4f8b

```
front,back,context,source,tag,type,flipped
"\u653e\u5f03\u3001\u629b\u5f03\uff08\u6b63\u5f0f\u7528\u8bed\uff09","abandon","They had to ___ the car in the snow.","\u96c5\u601d\u6838\u5fc3\u8bcd\u8868 List 3","\u5199\u4f5c\u9ad8\u9891","basic","0"
"\u6211\u60f3\u9884\u8ba2\u4e00\u5f20\u4e24\u4eba\u684c","Quisiera reservar una mesa para dos.","\u9910\u5385 \u00b7 \u9884\u8ba2","\u897f\u8bed\u751f\u5b58\u53e5 \u7b2c 1 \u8bfe","\u53e3\u8bed","speaking","0"
```

---

## \u516d\u3001\u66f4\u7b80\u5355\u7684\u7eaf\u6587\u672c\u683c\u5f0f

\u5982\u679c\u4e0d\u65b9\u4fbf\u8f93\u51fa CSV\uff0c\u4e5f\u53ef\u4ee5\u8f93\u51fa\u7eaf\u6587\u672c\uff1a\u7528 `!` \u5206\u9694\u6b63\u53cd\u9762\uff0c\u7528 `;` \u5206\u9694\u5361\u7247\u3002

```
\u653e\u5f03\u3001\u629b\u5f03\uff08\u6b63\u5f0f\u7528\u8bed\uff09!abandon;\u53ef\u6301\u7eed\u7684!sustainable;\u4eba\u4f53\u9762\u79ef\u6700\u5927\u7684\u5668\u5b98!\u76ae\u80a4
```

> \u6ce8\uff1a\u7eaf\u6587\u672c\u683c\u5f0f\u4e0d\u652f\u6301\u8bed\u5883\u5b57\u6bb5\uff0c\u4ec5\u9002\u5408\u5feb\u901f\u5f55\u5165\u3002\u9700\u8981\u8bed\u5883\u8bf7\u7528 CSV\u3002
''';

  /// 导出 CSV 模板，返回文件路径
  Future<String> exportCsvTemplate() async {
    final dir = await _templateDir();
    final file = File(p.join(dir, 'HermesCards_导入模板.csv'));
    await file.writeAsString(_csvTemplate, encoding: utf8);
    return file.path;
  }

  /// 导出 MD 规格文档（给 AI 助手读的），返回文件路径
  Future<String> exportMdTemplate() async {
    final dir = await _templateDir();
    final file = File(p.join(dir, 'HermesCards_导入规格_给AI读.md'));
    await file.writeAsString(_mdTemplate, encoding: utf8);
    return file.path;
  }

  Future<String> _templateDir() async {
    final dir = Directory(p.join(await _db.dataDirectory(), 'templates'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir.path;
  }

  /// 把文件字节解成字符串。
  ///
  /// 不能简单用 `String.fromCharCodes(bytes)`——那会把每个字节当成一个字符，
  /// UTF-8 中文会变乱码。这里按 BOM 判断 UTF-8 / UTF-16，并对无 BOM 的 UTF-16 做兜底。
  static String decodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    // UTF-8 BOM（Excel「CSV UTF-8」另存时会加）
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return _stripBom(utf8.decode(bytes.sublist(3), allowMalformed: true));
    }
    // UTF-16 BOM
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        return _stripBom(_decodeUtf16(bytes.sublist(2), true));
      }
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return _stripBom(_decodeUtf16(bytes.sublist(2), false));
      }
    }
    String s;
    try {
      s = utf8.decode(bytes);
    } catch (_) {
      // 解不开（多半是 GBK/ANSI 存的），先松散解出占位
      s = utf8.decode(bytes, allowMalformed: true);
    }
    // 无 BOM 的 UTF-16：按 UTF-8 解会掺进大量 \u0000
    if (s.contains('\u0000')) {
      final little = bytes.length > 1 && bytes[1] == 0;
      return _stripBom(_decodeUtf16(bytes, little));
    }
    // 不是合法 UTF-8（有替换符）时，尝试按 GBK/GB18030 解（中文 Windows、微信/QQ 传输常见）
    if (s.contains('\uFFFD')) {
      final gbkText = _tryDecodeGbk(bytes);
      if (gbkText != null && !gbkText.contains('\uFFFD')) {
        return _stripBom(gbkText);
      }
    }
    return _stripBom(s);
  }

  /// 尝试按 GBK 严格解码；不是合法 GBK 时返回 null。
  static String? _tryDecodeGbk(List<int> bytes) {
    try {
      return gbk.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  static String _stripBom(String s) =>
      s.startsWith('\uFEFF') ? s.substring(1) : s;

  static String _decodeUtf16(List<int> bytes, bool littleEndian) {
    final sb = StringBuffer();
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final a = bytes[i];
      final b = bytes[i + 1];
      final code = littleEndian ? ((b << 8) | a) : ((a << 8) | b);
      if (code == 0xFEFF) continue;
      sb.writeCharCode(code);
    }
    return sb.toString();
  }

  /// 表头别名：兼容中文表头（正面/反面/语境…）
  static const Map<String, List<String>> csvAliases = {
    'front': ['正面', '问题', 'question', 'prompt'],
    'back': ['反面', '答案', 'answer'],
    'context': ['语境', '例句', '上下文'],
    'source': ['来源', '出处'],
    'tag': ['标签', '分组', '分类'],
    'type': ['类型'],
    'flipped': ['翻转', '方向'],
  };

  /// 解析 CSV 内容为卡片（自动跳过表头，按字段名匹配）
  List<CardItem> parseCsv(String content, {required String deckId}) {
    final text = _stripBom(content);
    final delim = _detectDelimiter(text);
    final rows = _parseCsvRows(text, delim);
    if (rows.isEmpty) return [];

    // 定位表头：找包含 front（或其中文别名）的那一行
    final frontKeys = {'front', ...?csvAliases['front']};
    var headerIdx = -1;
    for (var i = 0; i < rows.length && i < 3; i++) {
      if (rows[i].any((e) => frontKeys.contains(e.trim().toLowerCase()))) {
        headerIdx = i;
        break;
      }
    }
    if (headerIdx < 0) return []; // 真的没有表头
    final header =
        rows[headerIdx].map((e) => e.trim().toLowerCase()).toList();

    int col(String name) {
      var i = header.indexOf(name);
      if (i >= 0) return i;
      for (final alias in csvAliases[name] ?? const []) {
        i = header.indexOf(alias.toLowerCase());
        if (i >= 0) return i;
      }
      return -1;
    }

    final iFront = col('front');
    final iBack = col('back');
    if (iFront < 0 || iBack < 0) return []; // 没有必需列，交给文本解析器兜底
    final iContext = col('context');
    final iSource = col('source');
    final iTag = col('tag');
    final iType = col('type');
    final iFlipped = col('flipped');

    final cards = <CardItem>[];
    for (var r = headerIdx + 1; r < rows.length; r++) {
      final row = rows[r];
      String at(int i) => (i >= 0 && i < row.length) ? row[i].trim() : '';
      final front = at(iFront);
      final back = at(iBack);
      if (front.isEmpty || back.isEmpty) continue;

      cards.add(CardItem(
        id: _genId(),
        deckId: deckId,
        front: front,
        back: back,
        context: at(iContext).isEmpty ? null : at(iContext),
        source: at(iSource).isEmpty ? null : at(iSource),
        tag: at(iTag).isEmpty ? null : at(iTag),
        type: _parseType(at(iType)),
        flipped: at(iFlipped) == '1',
      ));
    }
    return cards;
  }

  CardType _parseType(String s) {
    switch (s.toLowerCase()) {
      case 'cloze':
        return CardType.cloze;
      case 'speaking':
        return CardType.speaking;
      case 'multiplechoice':
        return CardType.multipleChoice;
      default:
        return CardType.basic;
    }
  }

  /// 识别分隔符：默认逗号；若表头行里没有逗号却有明显数量的分号 / Tab，就认那个。
  /// （部分 Excel 区域设置用分号做列表分隔符，导出的 CSV 会整个表头挤在一个字段里）
  static String _detectDelimiter(String content) {
    String? line;
    for (final l in content.split('\n')) {
      if (l.trim().isNotEmpty) {
        line = l;
        break;
      }
    }
    if (line == null) return ',';
    var comma = 0, semi = 0, tab = 0;
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (ch == ',') {
          comma++;
        } else if (ch == ';') {
          semi++;
        } else if (ch == '\t') {
          tab++;
        }
      }
    }
    if (comma > 0) return ',';
    if (semi == 0 && tab == 0) return ',';
    return semi >= tab ? ';' : '\t';
  }

  /// 轻量 CSV 解析：支持引号包裹、转义双引号、CRLF
  List<List<String>> _parseCsvRows(String content, [String delim = ',']) {
    final rows = <List<String>>[];
    final field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;

    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      if (row.any((e) => e.trim().isNotEmpty)) {
        rows.add(List<String>.from(row));
      }
      row = <String>[];
    }

    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == delim) {
          endField();
        } else if (ch == '\r' || ch == '\n') {
          if (ch == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
            i++;
          }
          endRow();
        } else {
          field.write(ch);
        }
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  static int _seq = 0;

  String _genId() =>
      'csv_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
}
