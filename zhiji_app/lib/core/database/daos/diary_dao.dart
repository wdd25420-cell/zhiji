import 'package:drift/drift.dart';
import '../app_database.dart';

part 'diary_dao.g.dart';

@DriftAccessor(tables: [DiaryEntries, DiaryTags, Tags])
class DiaryDao extends DatabaseAccessor<AppDatabase> with _$DiaryDaoMixin {
  DiaryDao(super.attachedDatabase);

  Future<int> insertEntry(DiaryEntriesCompanion entry) =>
      into(diaryEntries).insert(entry);

  /// 部分更新——只更新传入的字段，其余保留
  Future<int> updateEntry(int id, DiaryEntriesCompanion entry) =>
      (update(diaryEntries)..where((t) => t.id.equals(id))).write(entry);

  Future<int> deleteEntry(int id) async {
    // 先删关联标签
    await (delete(diaryTags)..where((tbl) => tbl.diaryEntryId.equals(id))).go();
    return (delete(diaryEntries)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 批量删除日记（含关联标签清理）
  Future<int> deleteEntries(List<int> ids) async {
    if (ids.isEmpty) return 0;
    await (delete(diaryTags)..where((tbl) => tbl.diaryEntryId.isIn(ids))).go();
    return (delete(diaryEntries)..where((tbl) => tbl.id.isIn(ids))).go();
  }

  Future<DiaryEntry?> getById(int id) =>
      (select(diaryEntries)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Stream<List<DiaryEntry>> watchAll() =>
      (select(diaryEntries)..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])).watch();

  Future<int> countAll() async {
    final result = await diaryEntries.count().getSingle();
    return result;
  }

  Future<List<DiaryEntry>> search(String query) {
    final q = '%$query%';
    return (select(diaryEntries)
          ..where((tbl) => tbl.title.like(q) | tbl.bodyMarkdown.like(q))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 查询包含指定标签的所有日记（按创建时间倒序）
  Future<List<DiaryEntry>> listByTag(int tagId) async {
    final query = select(diaryEntries).join([
      innerJoin(diaryTags, diaryTags.diaryEntryId.equalsExp(diaryEntries.id)),
    ]);
    query.where(diaryTags.tagId.equals(tagId));
    query.orderBy([OrderingTerm.desc(diaryEntries.createdAt)]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(diaryEntries)).toList();
  }

  /// 按情绪分组计数
  Future<Map<String, int>> countByEmotion() async {
    final rows = await attachedDatabase.customSelect(
      'SELECT emotion, COUNT(*) as cnt FROM diary_entries '
      'WHERE emotion IS NOT NULL GROUP BY emotion',
      readsFrom: {diaryEntries},
    ).get();
    return {for (final r in rows) r.read<String>('emotion'): r.read<int>('cnt')};
  }

  /// 当前连续记录天数（从今天往前数，遇到断档即停）
  Future<int> currentStreak() async {
    final rows = await attachedDatabase.customSelect(
      "SELECT DISTINCT created_at FROM diary_entries ORDER BY created_at DESC",
      readsFrom: {diaryEntries},
    ).get();
    if (rows.isEmpty) return 0;
    final days = rows
        .map((r) {
          final dt = r.read<DateTime>('created_at');
          return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        })
        .where((d) => d.isNotEmpty)
        .toSet();
    var streak = 0;
    var cursor = DateTime.now();
    for (;;) {
      final key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (days.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// 本周（近7天）总字数
  Future<int> wordCountThisWeek() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final rows = await attachedDatabase.customSelect(
      'SELECT COALESCE(SUM(LENGTH(body_markdown)),0) as w '
      'FROM diary_entries WHERE created_at >= ?',
      variables: [Variable.withDateTime(since)],
      readsFrom: {diaryEntries},
    ).get();
    return rows.first.read<int>('w');
  }

  /// 最近 N 天每天的条目数（热力图用）
  /// 日期分组在 Dart 端完成，避免 SQLite date() 时区/编码差异
  Future<Map<String, int>> countByDay(int days) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await attachedDatabase.customSelect(
      'SELECT created_at FROM diary_entries WHERE created_at >= ?',
      variables: [Variable.withDateTime(since)],
      readsFrom: {diaryEntries},
    ).get();
    final map = <String, int>{};
    for (final row in rows) {
      final key =
          '${row.read<DateTime>('created_at').year}-${row.read<DateTime>('created_at').month.toString().padLeft(2, '0')}-${row.read<DateTime>('created_at').day.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }
}
