import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:zhiji/core/database/app_database.dart';
import 'package:zhiji/core/database/daos/common_daos.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('数据库基础测试', () {
    test('日记 CRUD', () async {
      final id = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(
          title: '测试日记',
          bodyMarkdown: const Value('这是测试内容'),
          emotion: const Value('happy'),
        ),
      );
      expect(id, greaterThan(0));

      final entry = await db.diaryDao.getById(id);
      expect(entry, isNotNull);
      expect(entry!.title, '测试日记');
      expect(entry.emotion, 'happy');

      await db.diaryDao.deleteEntry(id);
      final deleted = await db.diaryDao.getById(id);
      expect(deleted, isNull);
    });

    test('知识条目 CRUD', () async {
      final id = await db.knowledgeDao.insertEntry(
        KnowledgeEntriesCompanion.insert(
          title: '测试知识',
          contentMarkdown: const Value('# 测试\n这是内容'),
          sourceUrl: const Value('https://example.com'),
        ),
      );
      expect(id, greaterThan(0));

      final entry = await db.knowledgeDao.getById(id);
      expect(entry, isNotNull);
      expect(entry!.title, '测试知识');
      expect(entry.sourceUrl, 'https://example.com');

      await db.knowledgeDao.deleteEntry(id);
      expect(await db.knowledgeDao.getById(id), isNull);
    });

    test('日记总数', () async {
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: 'D1', bodyMarkdown: const Value('...')),
      );
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: 'D2', bodyMarkdown: const Value('...')),
      );
      expect(await db.diaryDao.countAll(), 2);
    });

    test('知识库总数', () async {
      await db.knowledgeDao.insertEntry(
        KnowledgeEntriesCompanion.insert(title: 'K1', contentMarkdown: const Value('...')),
      );
      expect(await db.knowledgeDao.countAll(), 1);
    });
  });

  group('标签测试', () {
    test('创建和查询标签', () async {
      final tagDao = TagDao(db);
      final tag1 = await tagDao.getOrCreate('Flutter');
      expect(tag1.name, 'Flutter');
      expect(tag1.usageCount, 1);

      final tag2 = await tagDao.getOrCreate('Flutter');
      expect(tag2.id, tag1.id);
      expect(tag2.usageCount, 2);
    });

    test('标签关联日记', () async {
      final tagDao = TagDao(db);
      final tag = await tagDao.getOrCreate('测试标签');

      final diaryId = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: '带标签日记', bodyMarkdown: const Value('...')),
      );

      await tagDao.linkDiary(diaryId, tag.id);
      final tags = await tagDao.getForDiary(diaryId);
      expect(tags, contains(tag.id));
    });
  });

  group('设置测试', () {
    test('存取设置', () async {
      final settingsDao = SettingsDao(db);
      await settingsDao.setValue('api_key', 'sk-test-123');
      expect(await settingsDao.getValue('api_key'), 'sk-test-123');
      await settingsDao.remove('api_key');
      expect(await settingsDao.getValue('api_key'), isNull);
    });
  });

  group('分类预设', () {
    test('6 个预设分类存在', () async {
      final cats = await db.knowledgeDao.listCategories();
      expect(cats.length, 6);
      expect(cats.map((c) => c.name), containsAll([
        '技术开发', '产品设计', 'AI & 机器学习',
        '设计 & 体验', '阅读笔记', '工具 & 效率',
      ]));
    });
  });

  group('FTS5 搜索', () {
    test('搜索命中日记', () async {
      // 创建日记 → 触发器自动同步 FTS5 索引
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(
          title: 'Flutter开发笔记',
          bodyMarkdown: const Value('学习Flutter的状态管理和路由'),
        ),
      );

      final results = await db.search('Flutter');
      expect(results, isNotEmpty);
      expect(results.first['source_type'], 'diary');
    });

    test('搜索命中知识', () async {
      await db.knowledgeDao.insertEntry(
        KnowledgeEntriesCompanion.insert(
          title: 'DeepSeek API 使用指南',
          contentMarkdown: const Value('DeepSeek API 的调用方法和参数配置'),
        ),
      );

      final results = await db.search('DeepSeek');
      expect(results, isNotEmpty);
      expect(results.first['source_type'], 'knowledge');
    });

    test('搜索不存在的词返回空', () async {
      final results = await db.search('不存在的搜索词xyz123');
      expect(results, isEmpty);
    });
  });

  group('批量删除', () {
    test('批量删除日记', () async {
      final id1 = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: '日记1', bodyMarkdown: const Value('内容1')),
      );
      final id2 = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: '日记2', bodyMarkdown: const Value('内容2')),
      );
      final id3 = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: '日记3', bodyMarkdown: const Value('内容3')),
      );

      // 删除前两条
      final deleted = await db.diaryDao.deleteEntries([id1, id2]);
      expect(deleted, 2);

      // 第三条仍在
      expect(await db.diaryDao.getById(id3), isNotNull);
      // 已删除的返回 null
      expect(await db.diaryDao.getById(id1), isNull);
      expect(await db.diaryDao.getById(id2), isNull);
    });

    test('批量删除知识', () async {
      final id1 = await db.knowledgeDao.insertEntry(
        KnowledgeEntriesCompanion.insert(title: '知识1', contentMarkdown: const Value('内容1')),
      );
      final id2 = await db.knowledgeDao.insertEntry(
        KnowledgeEntriesCompanion.insert(title: '知识2', contentMarkdown: const Value('内容2')),
      );

      final deleted = await db.knowledgeDao.deleteEntries([id1, id2]);
      expect(deleted, 2);
      expect(await db.knowledgeDao.getById(id1), isNull);
      expect(await db.knowledgeDao.getById(id2), isNull);
    });

    test('删除空列表返回 0', () async {
      final deleted = await db.diaryDao.deleteEntries([]);
      expect(deleted, 0);
    });

    test('批量删除同时清理标签关联', () async {
      final diaryId = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: '标签测试', bodyMarkdown: const Value('内容')),
      );
      final tag = await TagDao(db).getOrCreate('测试标签');
      await TagDao(db).linkDiary(diaryId, tag.id);

      // 确认关联存在
      final before = await TagDao(db).getForDiary(diaryId);
      expect(before, isNotEmpty);

      // 批量删除
      await db.diaryDao.deleteEntries([diaryId]);

      // 日记删除后，关联也应清空
      final after = await TagDao(db).getForDiary(diaryId);
      expect(after, isEmpty);
    });
  });
}
