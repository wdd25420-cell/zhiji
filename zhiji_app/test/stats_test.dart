import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:zhiji/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('统计查询', () {
    test('countByEmotion 返回情绪分组正确', () async {
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: 'D1', bodyMarkdown: const Value('.'), emotion: const Value('happy')),
      );
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: 'D2', bodyMarkdown: const Value('.'), emotion: const Value('happy')),
      );
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: 'D3', bodyMarkdown: const Value('.'), emotion: const Value('calm')),
      );
      final map = await db.diaryDao.countByEmotion();
      expect(map['happy'], 2);
      expect(map['calm'], 1);
    });

    test('countByEmotion 空数据库返回空 Map', () async {
      final map = await db.diaryDao.countByEmotion();
      expect(map, isEmpty);
    });

    test('wordCountThisWeek 返回正字数', () async {
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: 'D1', bodyMarkdown: const Value('ABCDEF')),
      );
      final w = await db.diaryDao.wordCountThisWeek();
      expect(w, greaterThanOrEqualTo(6));
    });

    test('countByDay 不崩溃即可', () async {
      await db.diaryDao.insertEntry(
        DiaryEntriesCompanion.insert(title: 'HotEntry', bodyMarkdown: const Value('.')),);
      final map = await db.diaryDao.countByDay(7);
      // 基本能力验证：不抛异常、返回 Map
      expect(map, isA<Map<String, int>>());
    });
  });
}
