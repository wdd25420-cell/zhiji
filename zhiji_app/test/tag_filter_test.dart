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

  group('标签筛选 DAO', () {
    test('listByTag 只返回包含指定标签的日记', () async {
      // 建 2 篇日记
      final d1 = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: '含标签的日记', bodyMarkdown: const Value('这篇有标签')),
      );
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: '不含标签的日记', bodyMarkdown: const Value('这篇没有')),
      );

      // 创建标签并只关联 d1
      final tagDao = TagDao(db);
      final tag = await tagDao.getOrCreate('工作');
      await tagDao.linkDiary(d1, tag.id);

      // 查询
      final result = await db.diaryDao.listByTag(tag.id);
      expect(result.length, 1);
      expect(result.first.id, d1);
      expect(result.first.title, '含标签的日记');
    });

    test('listByTag 正文无标签名也能筛出', () async {
      final d1 = await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(
          title: '纯英文标题',
          bodyMarkdown: const Value('no chinese keyword here'),
        ),
      );
      final tagDao = TagDao(db);
      final tag = await tagDao.getOrCreate('工作');
      await tagDao.linkDiary(d1, tag.id);

      final result = await db.diaryDao.listByTag(tag.id);
      expect(result.length, 1);
      expect(result.first.title, '纯英文标题');
    });

    test('listByTag 未关联标签时返回空', () async {
      final result = await db.diaryDao.listByTag(999);
      expect(result, isEmpty);
    });
  });
}
