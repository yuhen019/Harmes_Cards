import 'dart:convert';

/// 卡片类型
/// 注：v1.2 起「反转卡」不再作为独立类型——翻转是通用能力（flipped 字段）。
/// 选择题卡降至 P2（测再认而非回忆，与主动回忆原则冲突）。
enum CardType {
  basic, // 基础问答
  cloze, // 填空
  speaking, // 开口卡（录音自评）P0 差异化核心
  multipleChoice, // 选择题（P2，暂不实现）
  reversed, // 已废弃，保留仅为兼容旧数据
}

/// 复习评分（对应 FSRS 四档）
enum ReviewGrade {
  again, // 重来
  hard, // 困难
  good, // 良好
  easy, // 简单
}

/// 卡片模型
class CardItem {
  final String id;
  String deckId;
  String front; // 正面（你看到什么）
  String back; // 反面（你要回忆什么）
  String? hint; // 提示
  String? tag; // 标签
  CardType type;
  String? imagePath; // 图片路径（可选）
  String? audioPath; // 音频路径（参考答案发音）
  String? recordingPath; // 开口卡：用户自己的录音

  /// C4 语境：出处原句 / 例句 / 上下文
  /// 孤立知识点调不出来——这是"认得但说不出"的解药
  String? context;

  /// C4 来源：文档名 / 集数 / 时间戳
  String? source;

  DateTime createdAt;
  DateTime updatedAt;

  /// C5 翻转方向：翻转是底层属性，不是一种题型
  /// false = 默认方向（front 提问 / back 回答）
  /// true  = 已翻转（back 提问 / front 回答）
  bool flipped;

  /// C3 Leech：连续 Again 累计次数（达到阈值自动暂停）
  int againCount;

  /// C3 是否已暂停（Leech 或手动挂起）
  bool suspended;

  /// L5 分批释放：false = 存为"待启用"，不进入学习队列
  bool enabled;

  // FSRS 记忆状态
  double stability; // 稳定性（天）
  double difficulty; // 难度 1-10
  double retrievability; // 可提取性 0-1
  int reps; // 复习次数
  int lapses; // 遗忘次数
  DateTime? due; // 下次复习时间
  String state; // new / learning / review / relearning

  CardItem({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.hint,
    this.tag,
    this.type = CardType.basic,
    this.imagePath,
    this.audioPath,
    this.recordingPath,
    this.context,
    this.source,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.flipped = false,
    this.againCount = 0,
    this.suspended = false,
    this.enabled = true,
    this.stability = 0,
    this.difficulty = 5,
    this.retrievability = 1.0,
    this.reps = 0,
    this.lapses = 0,
    this.due,
    this.state = 'new',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// C5 翻转：只翻方向标志，不交换字段。
  /// 注意：questionFace/answerFace 已按 flipped 做交换，
  /// 若这里再交换 front/back 就是双重反转（等于没翻）。
  /// 保留原始录入方向也便于追溯与同步合并。
  void flip() {
    flipped = !flipped;
    updatedAt = DateTime.now();
  }

  /// 当前显示用的提问面 / 回答面（受 flipped 影响）
  String get questionFace => flipped ? back : front;
  String get answerFace => flipped ? front : back;

  /// C3 是否为顽固卡
  bool isLeech(int threshold) => againCount >= threshold && suspended;

  Map<String, dynamic> toMap() => {
        'id': id,
        'deckId': deckId,
        'front': front,
        'back': back,
        'hint': hint,
        'tag': tag,
        'type': type.index,
        'imagePath': imagePath,
        'audioPath': audioPath,
        'recordingPath': recordingPath,
        'context': context,
        'source': source,
        'flipped': flipped ? 1 : 0,
        'againCount': againCount,
        'suspended': suspended ? 1 : 0,
        'enabled': enabled ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'stability': stability,
        'difficulty': difficulty,
        'retrievability': retrievability,
        'reps': reps,
        'lapses': lapses,
        'due': due?.toIso8601String(),
        'state': state,
      };

  factory CardItem.fromMap(Map<String, dynamic> m) => CardItem(
        id: m['id'],
        deckId: m['deckId'],
        front: m['front'],
        back: m['back'],
        hint: m['hint'],
        tag: m['tag'],
        type: CardType.values[m['type'] ?? 0],
        imagePath: m['imagePath'],
        audioPath: m['audioPath'],
        recordingPath: m['recordingPath'],
        context: m['context'],
        source: m['source'],
        flipped: (m['flipped'] ?? 0) == 1,
        againCount: m['againCount'] ?? 0,
        suspended: (m['suspended'] ?? 0) == 1,
        enabled: (m['enabled'] ?? 1) == 1,
        createdAt: DateTime.parse(m['createdAt']),
        updatedAt: DateTime.parse(m['updatedAt']),
        stability: (m['stability'] ?? 0).toDouble(),
        difficulty: (m['difficulty'] ?? 5).toDouble(),
        retrievability: (m['retrievability'] ?? 1.0).toDouble(),
        reps: m['reps'] ?? 0,
        lapses: m['lapses'] ?? 0,
        due: m['due'] != null ? DateTime.parse(m['due']) : null,
        state: m['state'] ?? 'new',
      );

  String toJson() => jsonEncode(toMap());
  factory CardItem.fromJson(String s) => CardItem.fromMap(jsonDecode(s));
}
