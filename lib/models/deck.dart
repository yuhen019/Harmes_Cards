import 'dart:convert';

/// 牌组（卡包）模型
class Deck {
  final String id;
  String name;
  String emoji; // 封面 emoji
  int colorValue; // 主题色 int
  String? description;
  String? tag;
  DateTime createdAt;
  DateTime updatedAt;
  bool archived;

  Deck({
    required this.id,
    required this.name,
    this.emoji = '📚',
    this.colorValue = 0xFF5DCAA5,
    this.description,
    this.tag,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.archived = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorValue': colorValue,
        'description': description,
        'tag': tag,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'archived': archived ? 1 : 0,
      };

  factory Deck.fromMap(Map<String, dynamic> m) => Deck(
        id: m['id'],
        name: m['name'],
        emoji: m['emoji'] ?? '📚',
        colorValue: m['colorValue'] ?? 0xFF5DCAA5,
        description: m['description'],
        tag: m['tag'],
        createdAt: DateTime.parse(m['createdAt']),
        updatedAt: DateTime.parse(m['updatedAt']),
        archived: (m['archived'] ?? 0) == 1,
      );

  String toJson() => jsonEncode(toMap());
  factory Deck.fromJson(String s) => Deck.fromMap(jsonDecode(s));
}
