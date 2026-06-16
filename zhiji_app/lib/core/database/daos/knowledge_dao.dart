import 'package:drift/drift.dart';
import '../app_database.dart';

part 'knowledge_dao.g.dart';

@DriftAccessor(tables: [KnowledgeEntries, KnowledgeTags, Tags, CategoryModels])
class KnowledgeDao extends DatabaseAccessor<AppDatabase> with _$KnowledgeDaoMixin {
  KnowledgeDao(super.attachedDatabase);

  Future<int> insertEntry(KnowledgeEntriesCompanion entry) =>
      into(knowledgeEntries).insert(entry);

  /// 部分更新——只更新传入的字段，其余保留
  Future<int> updateEntry(int id, KnowledgeEntriesCompanion entry) =>
      (update(knowledgeEntries)..where((t) => t.id.equals(id))).write(entry);

  Future<int> deleteEntry(int id) async {
    await (delete(knowledgeTags)..where((tbl) => tbl.knowledgeEntryId.equals(id))).go();
    return (delete(knowledgeEntries)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 批量删除知识条目（含关联标签清理）
  Future<int> deleteEntries(List<int> ids) async {
    if (ids.isEmpty) return 0;
    await (delete(knowledgeTags)..where((tbl) => tbl.knowledgeEntryId.isIn(ids))).go();
    return (delete(knowledgeEntries)..where((tbl) => tbl.id.isIn(ids))).go();
  }

  Future<KnowledgeEntry?> getById(int id) =>
      (select(knowledgeEntries)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Stream<List<KnowledgeEntry>> watchAll() =>
      (select(knowledgeEntries)
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
          .watch();

  Stream<List<KnowledgeEntry>> watchByCategory(int categoryId) =>
      (select(knowledgeEntries)
            ..where((tbl) => tbl.categoryId.equals(categoryId))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
          .watch();

  Future<int> countAll() async {
    final result = await knowledgeEntries.count().getSingle();
    return result;
  }

  Future<int> countByCategory(int categoryId) async {
    final query = selectOnly(knowledgeEntries)
      ..addColumns([knowledgeEntries.id.count()])
      ..where(knowledgeEntries.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(knowledgeEntries.id.count()) as int;
  }

  Future<List<KnowledgeEntry>> listRecent(int limit) =>
      (select(knowledgeEntries)
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
            ..limit(limit))
          .get();

  Future<List<CategoryModel>> listCategories() =>
      (select(categoryModels)..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)])).get();

  /// 基于共同标签的关联推荐（排除自身）
  Future<List<KnowledgeEntry>> listRelatedByTags(int entryId, List<int> tagIds, {int limit = 3}) async {
    if (tagIds.isEmpty) return [];
    final query = select(knowledgeEntries).join([
      innerJoin(knowledgeTags, knowledgeTags.knowledgeEntryId.equalsExp(knowledgeEntries.id)),
    ]);
    query.where(knowledgeTags.tagId.isIn(tagIds) & knowledgeEntries.id.isNotValue(entryId));
    query.orderBy([OrderingTerm.desc(knowledgeEntries.createdAt)]);
    query.limit(limit);
    final rows = await query.get();
    return rows.map((r) => r.readTable(knowledgeEntries)).toList();
  }
}
