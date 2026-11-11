import 'dart:math';
import '../models/card_item.dart';

/// FSRS（Free Spaced Repetition Scheduler）调度器
///
/// 公式严格对齐 open-spaced-repetition 官方 Wiki 的 **FSRS-4.5**（17 参数）：
/// https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm
///   D0(G) = w4 - (G-3)*w5                     （4.5 是线性式，不是 5/6 的指数式）
///   D'    = w7*D0(3) + (1-w7)*(D - w6*(G-3))  （无阻尼，回归目标 D0(3)）
///   S'r   = S*(1 + e^w8*(11-D)*S^-w9*(e^(w10*(1-R))-1)*w15[G=2]*w16[G=4])
///   S'f   = w11*D^-w12*((S+1)^w13 - 1)*e^(w14*(1-R))
///   R(t,S)= (1 + 19/81 * t/S)^-0.5，t = 距上一次复习的天数（不是距到期日）
class FsrsScheduler {
  // FSRS-4.5 默认参数（open-spaced-repetition 公开的默认权重）
  static const List<double> _defaultParams = [
    0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031,
    1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755,
  ];

  /// 目标保持率（默认 90%）
  double desiredRetention;

  /// 学习步骤（分钟）：新卡/遗忘卡在当天先用短间隔过一遍
  List<double> learningSteps;

  /// C6 新卡毕业间隔（天）：新卡评 Hard/Good 后进入正式复习的间隔
  int graduatingIntervalDays;

  /// C6 简单间隔（天）：新卡评 Easy 后的间隔
  int easyIntervalDays;

  FsrsScheduler({
    this.desiredRetention = 0.90,
    List<double>? learningSteps,
    this.graduatingIntervalDays = 3,
    this.easyIntervalDays = 4,
  }) : learningSteps = learningSteps ?? [1, 10];

  /// 幂律遗忘曲线：距上次复习 t 天后，可提取率 R(t,S)
  double _forgettingCurve(double elapsedDays, double stability) {
    const decay = -0.5;
    const factor = 19 / 81;
    final t = elapsedDays / stability;
    return pow(1 + factor * t, decay).toDouble();
  }

  /// 根据目标保持率计算下次复习间隔（天）
  double _nextInterval(double stability) {
    const decay = -0.5;
    const factor = 19 / 81;
    final r = desiredRetention;
    final interval = stability / factor * (pow(r, 1 / decay) - 1);
    return interval;
  }

  /// 初始难度 D0(G) = w4 - (G-3)*w5（FSRS-4.5 线性式）
  double _initDifficulty(int grade) {
    final w4 = _defaultParams[4];
    final w5 = _defaultParams[5];
    return (w4 - (grade - 3) * w5).clamp(1.0, 10.0);
  }

  /// 难度更新：D' = w7*D0(3) + (1-w7)*(D - w6*(G-3))，D0(3)=w4
  double _nextDifficulty(double d, int grade) {
    final w4 = _defaultParams[4];
    final w6 = _defaultParams[6];
    final w7 = _defaultParams[7];
    final damped = d - w6 * (grade - 3);
    return (w7 * w4 + (1 - w7) * damped).clamp(1.0, 10.0);
  }

  /// 复习成功后的新稳定性 S'r（G=2,3,4）
  double _stabilityAfterSuccess(double s, double d, double r, int grade) {
    final w8 = _defaultParams[8];
    final w9 = _defaultParams[9];
    final w10 = _defaultParams[10];
    final w15 = _defaultParams[15];
    final w16 = _defaultParams[16];

    final hardPenalty = grade == 2 ? w15 : 1.0;
    final easyBonus = grade == 4 ? w16 : 1.0;
    final rFactor = exp(w10 * (1 - r)) - 1;

    return s *
        (1 +
            exp(w8) *
                (11 - d) *
                pow(s, -w9) *
                rFactor *
                hardPenalty *
                easyBonus);
  }

  /// 复习失败后的新稳定性 S'f = w11*D^-w12*((S+1)^w13 - 1)*e^(w14*(1-R))
  double _stabilityAfterFailure(double s, double d, double r) {
    final w11 = _defaultParams[11];
    final w12 = _defaultParams[12];
    final w13 = _defaultParams[13];
    final w14 = _defaultParams[14];

    final newS = w11 *
        pow(d, -w12) *
        (pow(s + 1, w13) - 1) *
        exp(w14 * (1 - r));
    // 遗忘后稳定性不应超过遗忘前
    return newS.clamp(0.0, s).toDouble();
  }

  /// 处理一次复习评分，返回更新后的卡片。
  /// 除 FSRS 字段外，原卡的语境/来源/翻转/启用/暂停/Leech 计数等全部保留。
  CardItem review(CardItem card, ReviewGrade grade, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final g = grade.index + 1; // again=1, hard=2, good=3, easy=4
    final s = card.stability;
    final d = card.difficulty;
    final isNew = card.state == 'new' || s <= 0;

    // R 的 elapsed = 距上一次复习的天数（updatedAt 在每次复习时刷新）
    final elapsed = t
        .difference(card.updatedAt)
        .inMilliseconds
        .toDouble()
        .clamp(0.0, 3650.0 * 86400000.0) /
        86400000.0;
    final r = s > 0 ? _forgettingCurve(elapsed, s) : 1.0;

    double newS, newD;
    DateTime? newDue;
    String newState;

    if (g == 1) {
      // Again：遗忘 → 回学习步骤，短间隔后重来
      newS = isNew
          ? _defaultParams[0]
          : _stabilityAfterFailure(s, d, r);
      newD = isNew ? _initDifficulty(1) : _nextDifficulty(d, 1);
      newDue = t.add(Duration(minutes: learningSteps.first.round()));
      newState = 'learning';
    } else if (isNew) {
      // 新卡首次答对：初始稳定性 + 初始难度，按毕业/简单间隔进入复习
      newS = _defaultParams[g - 1];
      newD = _initDifficulty(g);
      final days = g == 4 ? easyIntervalDays : graduatingIntervalDays;
      newDue = t.add(Duration(days: days));
      newState = 'review';
    } else {
      // 老卡答对：FSRS 正常推进
      newS = _stabilityAfterSuccess(s, d, r, g);
      newD = _nextDifficulty(d, g);
      final day = _nextInterval(newS).round().clamp(1, 36500);
      newDue = t.add(Duration(days: day));
      newState = 'review';
    }

    // 全字段复制，仅覆盖调度相关字段（此前重建丢字段导致 C3/C4/C5 失效）
    return CardItem(
      id: card.id,
      deckId: card.deckId,
      front: card.front,
      back: card.back,
      hint: card.hint,
      tag: card.tag,
      type: card.type,
      imagePath: card.imagePath,
      audioPath: card.audioPath,
      recordingPath: card.recordingPath,
      context: card.context,
      source: card.source,
      createdAt: card.createdAt,
      updatedAt: t,
      flipped: card.flipped,
      againCount: card.againCount,
      suspended: card.suspended,
      enabled: card.enabled,
      stability: newS,
      difficulty: newD,
      retrievability: r,
      reps: card.reps + 1,
      lapses: card.lapses + (g == 1 ? 1 : 0),
      due: newDue,
      state: newState,
    );
  }

  /// 是否到期（可复习）。新卡不属于「待复习」，由新卡队列单独处理，
  /// 否则新卡会被重复计入待复习和学习队列。
  bool isDue(CardItem card, DateTime now) {
    if (card.state == 'new') return false;
    if (card.due == null) return true;
    return !now.isBefore(card.due!);
  }
}
