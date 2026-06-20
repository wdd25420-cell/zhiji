import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app_database.dart';
import '../../network/dio_client.dart';

class TagDao {
  final AppDatabase _db;
  TagDao(this._db);

  Future<Tag?> getByName(String name) =>
      (_db.select(_db.tags)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<List<Tag>> listAll() => _db.select(_db.tags).get();

  Future<Tag> getOrCreate(String name) async {
    // 单条 SQL 原子操作——INSERT OR UPDATE，无竞态条件
    await _db.customStatement(
      'INSERT INTO tags (name, usage_count) VALUES (?, 1) '
      'ON CONFLICT(name) DO UPDATE SET usage_count = usage_count + 1',
      [name],
    );
    final tag = await getByName(name);
    if (tag == null) throw StateError('getOrCreate failed for: $name');
    return tag;
  }

  Future<void> linkDiary(int diaryId, int tagId) async {
    await _db.into(_db.diaryTags).insert(
          DiaryTagsCompanion.insert(diaryEntryId: diaryId, tagId: tagId),
        );
  }

  Future<void> linkKnowledge(int knowledgeId, int tagId) async {
    await _db.into(_db.knowledgeTags).insert(
          KnowledgeTagsCompanion.insert(knowledgeEntryId: knowledgeId, tagId: tagId),
        );
  }

  Future<List<int>> getForDiary(int diaryId) async {
    final rows = await (_db.select(_db.diaryTags)
          ..where((t) => t.diaryEntryId.equals(diaryId)))
        .get();
    return rows.map((r) => r.tagId).toList();
  }

  Future<List<int>> getForKnowledge(int knowledgeId) async {
    final rows = await (_db.select(_db.knowledgeTags)
          ..where((t) => t.knowledgeEntryId.equals(knowledgeId)))
        .get();
    return rows.map((r) => r.tagId).toList();
  }
}

class SettingsDao {
  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;
  SettingsDao(this._db) : _secureStorage = const FlutterSecureStorage();

  Future<void> setApiKey(String value) async {
    await _secureStorage.write(key: 'api_key', value: value);
    // 立即应用到 Dio 客户端，无需重启
    AppDio.setApiKey(value);
  }

  Future<String?> getApiKey() async =>
      _secureStorage.read(key: 'api_key');

  Future<void> deleteApiKey() async =>
      _secureStorage.delete(key: 'api_key');

  Future<void> setBingKey(String value) async {
    await _secureStorage.write(key: 'bing_key', value: value);
  }

  Future<String?> getBingKey() async =>
      _secureStorage.read(key: 'bing_key');

  Future<String?> getValue(String key) async {
    final row = await (_db.select(_db.settingsTable)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) async {
    await _db.into(_db.settingsTable).insertOnConflictUpdate(
          SettingsTableData(key: key, value: value),
        );
  }

  Future<void> remove(String key) async {
    await (_db.delete(_db.settingsTable)..where((t) => t.key.equals(key))).go();
  }
}
