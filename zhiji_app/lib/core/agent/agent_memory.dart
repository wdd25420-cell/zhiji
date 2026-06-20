import "dart:convert";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:zhiji/core/database/app_database.dart";
import "package:zhiji/core/database/daos/common_daos.dart";

/// 用户偏好记忆——持久化到 settings_table 的 agent_memory JSON
class AgentMemory {
  static const _key = "agent_memory";

  List<String> interests;
  List<int> preferredCategories;
  List<String> recentTopics;
  String? lastSummarized;

  AgentMemory({
    List<String>? interests,
    List<int>? preferredCategories,
    List<String>? recentTopics,
    this.lastSummarized,
  })  : interests = interests ?? [],
        preferredCategories = preferredCategories ?? [],
        recentTopics = recentTopics ?? [];

  /// 从 SettingsDao 加载记忆
  static Future<AgentMemory> load(SettingsDao dao) async {
    final raw = await dao.getValue(_key);
    if (raw == null || raw.isEmpty) return AgentMemory();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AgentMemory(
        interests: (json["interests"] as List?)?.cast<String>() ?? [],
        preferredCategories: (json["preferredCategories"] as List?)?.cast<int>() ?? [],
        recentTopics: (json["recentTopics"] as List?)?.cast<String>() ?? [],
        lastSummarized: json["lastSummarized"] as String?,
      );
    } catch (_) {
      return AgentMemory();
    }
  }

  /// 持久化到 SettingsDao
  Future<void> save(SettingsDao dao) async {
    await dao.setValue(_key, jsonEncode(toJson()));
  }

  /// 追加近期话题（去重，最多保留 10 条）
  void addRecentTopic(String topic) {
    recentTopics.remove(topic);
    recentTopics.insert(0, topic);
    if (recentTopics.length > 10) {
      recentTopics = recentTopics.sublist(0, 10);
    }
  }

  /// 更新分类使用频率
  void touchCategory(int categoryId) {
    preferredCategories.remove(categoryId);
    preferredCategories.insert(0, categoryId);
    if (preferredCategories.length > 10) {
      preferredCategories = preferredCategories.sublist(0, 10);
    }
  }

  /// 生成注入 system prompt 的文本
  String toSystemPromptFragment() {
    final parts = <String>[];
    if (interests.isNotEmpty) {
      parts.add("用户感兴趣的话题：${interests.join("、")}。");
    }
    if (recentTopics.isNotEmpty) {
      parts.add("用户最近关注的话题：${recentTopics.take(5).join("、")}。");
    }
    if (parts.isEmpty) return "";
    return "\n\n[用户偏好]\n${parts.join("\n")}";
  }

  Map<String, dynamic> toJson() => {
        "interests": interests,
        "preferredCategories": preferredCategories,
        "recentTopics": recentTopics,
        if (lastSummarized != null) "lastSummarized": lastSummarized,
      };
}

/// AgentMemory 的 StateNotifier——自动从 DB 加载、写回
class AgentMemoryNotifier extends StateNotifier<AgentMemory> {
  AgentMemoryNotifier(this._db) : super(AgentMemory()) {
    _init();
  }

  final AppDatabase _db;
  bool _ready = false;

  Future<void> _init() async {
    final dao = SettingsDao(_db);
    state = await AgentMemory.load(dao);
    _ready = true;
  }

  /// 追加近期话题并持久化
  Future<void> addRecentTopic(String topic) async {
    if (!_ready) return;
    state.addRecentTopic(topic);
    final dao = SettingsDao(_db);
    await state.save(dao);
  }

  /// 更新分类使用频率并持久化
  Future<void> touchCategory(int categoryId) async {
    if (!_ready) return;
    state.touchCategory(categoryId);
    final dao = SettingsDao(_db);
    await state.save(dao);
  }
}

/// T12: 用户偏好记忆 Provider——下游可 watch 获取当前记忆快照
final agentMemoryProvider = StateNotifierProvider<AgentMemoryNotifier, AgentMemory>(
  (ref) {
    final db = ref.watch(databaseProvider).value!;
    return AgentMemoryNotifier(db);
  },
);
