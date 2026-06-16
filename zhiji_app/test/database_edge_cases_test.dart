import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:zhiji/core/database/app_database.dart';
import 'package:zhiji/core/database/daos/common_daos.dart';
import 'package:zhiji/core/models/emotion.dart';
import 'package:zhiji/core/network/dio_client.dart';

void main() {
  late AppDatabase db;

  setUp(() async { db = AppDatabase(NativeDatabase.memory()); });
  tearDown(() async { await db.close(); });

  // ==================== 边界值 ====================
  group('约束与边界值', () {
    test('空标题日记应抛异常', () async {
      expect(() => db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: '', bodyMarkdown: const Value('body'))), throwsA(anything));
    });

    test('空标题知识条目应抛异常', () async {
      expect(() => db.knowledgeDao.insertEntry(KnowledgeEntriesCompanion.insert(title: '', contentMarkdown: const Value('body'))), throwsA(anything));
    });

    test('超长标题(>200字符)应抛异常', () async {
      expect(() => db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: 'A'*201, bodyMarkdown: const Value('body'))), throwsA(anything));
    });

    test('emotion=null 的日记插入和查询正常', () async {
      final id = await db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: '无情绪日记', bodyMarkdown: const Value('...')));
      expect((await db.diaryDao.getById(id))!.emotion, isNull);
    });

    test('categoryId=null 的知识条目正常', () async {
      final id = await db.knowledgeDao.insertEntry(KnowledgeEntriesCompanion.insert(title: '无分类条目', contentMarkdown: const Value('...')));
      expect((await db.knowledgeDao.getById(id))!.categoryId, isNull);
    });

    test('查询不存在的ID返回null', () async {
      expect(await db.diaryDao.getById(99999), isNull);
    });
  });

  // ==================== 并发与冲突 ====================
  group('并发与数据冲突', () {
    test('重复 link 同一标签到同一条目应抛主键冲突', () async {
      final tagDao = TagDao(db);
      final tag = await tagDao.getOrCreate('重复标签');
      final diaryId = await db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: '测试', bodyMarkdown: const Value('...')));
      await tagDao.linkDiary(diaryId, tag.id);
      expect(() => tagDao.linkDiary(diaryId, tag.id), throwsA(anything));
    });
  });

  // ==================== FTS5 搜索 ====================
  group('FTS5 搜索边界', () {
    setUp(() async {
      await db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: 'Flutter 状态管理', bodyMarkdown: const Value('Provider, Riverpod')));
      await db.knowledgeDao.insertEntry(KnowledgeEntriesCompanion.insert(title: 'Riverpod 最佳实践', contentMarkdown: const Value('如何正确使用 Riverpod')));
    });

    test('空字符串搜索返回空', () async {
      expect(await db.search(''), isEmpty);
    });

    test('纯空格搜索返回空', () async {
      expect(await db.search('   '), isEmpty);
    });

    test('FTS5 特殊字符不会崩溃 (^ * " ( ))', () async {
      final results = await db.search('Flutter OR State* "test" (Riverpod)');
      expect(results, isA<List>());
    });

    test('更新条目后 FTS5 索引同步', () async {
      final before = await db.search('Flutter');
      if (before.isNotEmpty) {
        final id = before.first['source_id'] as int;
        await db.diaryDao.updateEntry(id, DiaryEntriesCompanion(title: const Value('已修改标题'), bodyMarkdown: const Value('新内容')));
        final after = await db.search('Flutter');
        expect(after.length, lessThan(before.length));
      }
    });

    test('删除条目后 FTS5 索引清除', () async {
      final before = await db.search('Riverpod');
      if (before.isNotEmpty) {
        await db.diaryDao.deleteEntry(before.first['source_id'] as int);
        final after = await db.search('Riverpod');
        expect(after.length, lessThan(before.length));
      }
    });

    test('搜索 diary 和 knowledge 均返回', () async {
      final results = await db.search('Riverpod');
      final types = results.map((r) => r['source_type']).toSet();
      expect(types, containsAll(['diary', 'knowledge']));
    });
  });

  // ==================== DAO 补充 ====================
  group('DAO 补充操作', () {
    test('DiaryDao.updateEntry 更新后读取', () async {
      final id = await db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: '原始标题', bodyMarkdown: const Value('原始内容')));
      await db.diaryDao.updateEntry(id, DiaryEntriesCompanion(title: const Value('修改后标题'), bodyMarkdown: const Value('修改后内容')));
      final updated = await db.diaryDao.getById(id);
      expect(updated!.title, '修改后标题');
    });

    test('DiaryDao.watchAll stream 发送数据', () async {
      await db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: 'S1', bodyMarkdown: const Value('...')));
      final entries = await db.diaryDao.watchAll().first;
      expect(entries, isNotEmpty);
    });

    test('DiaryDao.search like查询', () async {
      await db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: '我的测试', bodyMarkdown: const Value('某个关键词在这里')));
      expect(await db.diaryDao.search('关键词'), isNotEmpty);
      expect(await db.diaryDao.search('不存在'), isEmpty);
    });

    test('KnowledgeDao.watchByCategory stream 筛选', () async {
      final cats = await db.knowledgeDao.listCategories();
      await db.knowledgeDao.insertEntry(KnowledgeEntriesCompanion.insert(title: 'K1', contentMarkdown: const Value('...'), categoryId: Value(cats.first.id)));
      await db.knowledgeDao.insertEntry(KnowledgeEntriesCompanion.insert(title: 'K2', contentMarkdown: const Value('...'), categoryId: Value(cats.first.id)));
      final entries = await db.knowledgeDao.watchByCategory(cats.first.id).first;
      expect(entries.length, 2);
    });

    test('KnowledgeDao.listRecent 限制数量', () async {
      for (int i = 0; i < 5; i++) { await db.knowledgeDao.insertEntry(KnowledgeEntriesCompanion.insert(title: 'K$i', contentMarkdown: const Value('...'))); }
      expect((await db.knowledgeDao.listRecent(3)).length, 3);
    });

    test('KnowledgeDao.countByCategory 计数', () async {
      final cats = await db.knowledgeDao.listCategories();
      await db.knowledgeDao.insertEntry(KnowledgeEntriesCompanion.insert(title: 'X', contentMarkdown: const Value('...'), categoryId: Value(cats.first.id)));
      expect(await db.knowledgeDao.countByCategory(cats.first.id), 1);
    });

    test('deleteEntry 级联删除关联标签', () async {
      final tagDao = TagDao(db);
      final tag = await tagDao.getOrCreate('级联标签');
      final diaryId = await db.diaryDao.insertEntry(DiaryEntriesCompanion.insert(title: 'X', bodyMarkdown: const Value('...')));
      await tagDao.linkDiary(diaryId, tag.id);
      await db.diaryDao.deleteEntry(diaryId);
      expect(await db.diaryDao.getById(diaryId), isNull);
    });
  });

  // ==================== TagDao ====================
  group('TagDao 补充', () {
    test('getByName 找到和未找到', () async {
      final tagDao = TagDao(db);
      await tagDao.getOrCreate('测试标签');
      expect((await tagDao.getByName('测试标签'))!.name, '测试标签');
      expect(await tagDao.getByName('不存在的标签'), isNull);
    });

    test('getOrCreate 多次调用 usageCount 递增', () async {
      final tagDao = TagDao(db);
      expect((await tagDao.getOrCreate('Flutter')).usageCount, 1);
      expect((await tagDao.getOrCreate('Flutter')).usageCount, 2);
      expect((await tagDao.getOrCreate('Flutter')).usageCount, 3);
    });

    test('listAll 返回所有标签', () async {
      final tagDao = TagDao(db);
      await tagDao.getOrCreate('A');
      await tagDao.getOrCreate('B');
      expect((await tagDao.listAll()).length, 2);
    });
  });

  // ==================== SettingsDao ====================
  group('SettingsDao 补充', () {
    test('insertOnConflictUpdate 覆盖旧值', () async {
      final s = SettingsDao(db);
      await s.setValue('theme', 'light');
      await s.setValue('theme', 'dark');
      expect(await s.getValue('theme'), 'dark');
    });

    test('getValue 未设置的key返回null', () async {
      expect(await SettingsDao(db).getValue('未设置的key'), isNull);
    });

    test('多个键值对并存', () async {
      final s = SettingsDao(db);
      await s.setValue('k1', 'v1');
      await s.setValue('k2', 'v2');
      expect(await s.getValue('k1'), 'v1');
      expect(await s.getValue('k2'), 'v2');
    });
  });

  // ==================== Emotion ====================
  group('Emotion 枚举', () {
    test('8 个情绪完整', () { expect(Emotion.values.length, 8); });
    test('每个情绪都有非空 emoji 和 label', () {
      for (final e in Emotion.values) {
        expect(e.emoji, isNotEmpty);
        expect(e.label, isNotEmpty);
      }
    });
  });

  // ==================== DioClient ====================
  group('DioClient', () {
    test('单例返回同一实例', () {
      expect(identical(AppDio.instance, AppDio.instance), true);
    });
    test('setApiKey 注入 Bearer Token', () {
      AppDio.setApiKey('sk-test-abc123');
      expect(AppDio.instance.options.headers['Authorization'], 'Bearer sk-test-abc123');
    });
  });
}
