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

  group('集成：日记→标签→FTS5 全链路', () {
    test('写日记→打标签→FTS5搜索→删日记→FTS5清除', () async {
      final tagDao = TagDao(db);

      // 1. 创建日记
      final id = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(
          title: 'DeepSeek 使用心得',
          bodyMarkdown: const Value('DeepSeek 的 API 调用非常方便，支持流式输出和多轮对话'),
        ),
      );

      // 2. 打标签
      final tag1 = await tagDao.getOrCreate('AI');
      final tag2 = await tagDao.getOrCreate('API');
      await tagDao.linkDiary(id, tag1.id);
      await tagDao.linkDiary(id, tag2.id);

      // 3. 验证标签关联
      final tags = await tagDao.getForDiary(id);
      expect(tags, containsAll([tag1.id, tag2.id]));

      // 4. FTS5 搜索能找到
      final results = await db.search('DeepSeek');
      expect(results.any((r) => r['source_id'] == id), isTrue);

      // 5. 标签筛选能找到
      final byTag = await db.diaryDao.listByTag(tag1.id);
      expect(byTag.any((e) => e.id == id), isTrue);

      // 6. 删除日记
      await db.diaryDao.deleteEntry(id);

      // 7. FTS5 已清除
      final afterDelete = await db.search('DeepSeek');
      expect(afterDelete.any((r) => r['source_id'] == id), isFalse);

      // 8. 标签关联已清空
      final tagsAfter = await tagDao.getForDiary(id);
      expect(tagsAfter, isEmpty);
    });
  });

  group('集成：知识→分类→关联推荐', () {
    test('同标签知识条目关联推荐正确', () async {
      final tagDao = TagDao(db);

      // 1. 创建知识条目 1
      final id1 = await db.knowledgeDao.insertEntry(
        KnowledgeEntriesCompanion.insert(
          title: 'Flutter 状态管理',
          contentMarkdown: const Value('Riverpod vs BLoC 对比'),
          categoryId: const Value(1), // 技术开发
        ),
      );

      // 2. 创建知识条目 2
      final id2 = await db.knowledgeDao.insertEntry(
        KnowledgeEntriesCompanion.insert(
          title: 'Dart 异步编程',
          contentMarkdown: const Value('Future 和 Stream 详解'),
          categoryId: const Value(1),
        ),
      );

      // 3. 打相同标签
      final flutterTag = await tagDao.getOrCreate('Flutter');
      await tagDao.linkKnowledge(id1, flutterTag.id);
      await tagDao.linkKnowledge(id2, flutterTag.id);

      // 4. 获取关联推荐
      final related = await db.knowledgeDao.listRelatedByTags(
        id1,
        [flutterTag.id],
      );
      expect(related.any((e) => e.id == id2), isTrue);
      expect(related.any((e) => e.id == id1), isFalse); // 排除自身

      // 5. 分类筛选
      final byCat = await db.knowledgeDao.watchByCategory(1).first;
      expect(byCat.length, greaterThanOrEqualTo(2));
    });
  });

  group('集成：统计查询', () {
    test('情绪统计和字数统计正确', () async {
      // 插入多条带情绪的日记
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(
          title: '今天很开心',
          bodyMarkdown: const Value('天气真好，适合出去走走'),
          emotion: const Value('happy'),
        ),
      );
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(
          title: '有点焦虑',
          bodyMarkdown: const Value('工作压力大，需要调整心态'),
          emotion: const Value('anxious'),
        ),
      );
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(
          title: '平静的一天',
          bodyMarkdown: const Value('按计划完成了所有任务'),
          emotion: const Value('calm'),
        ),
      );

      // 情绪统计
      final emotionCount = await db.diaryDao.countByEmotion();
      expect(emotionCount['happy'], 1);
      expect(emotionCount['anxious'], 1);
      expect(emotionCount['calm'], 1);

      // 字数统计
      final words = await db.diaryDao.wordCountThisWeek();
      expect(words, greaterThan(0));

      // 计数
      final count = await db.diaryDao.countAll();
      expect(count, 3);
    });
  });
}
