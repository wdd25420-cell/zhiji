import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart' show applyWorkaroundToOpenSqlite3OnOldAndroidVersions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'daos/diary_dao.dart';
import 'daos/knowledge_dao.dart';
import 'retry_on_lock.dart';

part 'app_database.g.dart';

class DiaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get bodyMarkdown => text().withDefault(const Constant(''))();
  TextColumn get emotion => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get aiSummary => text().nullable()();
  TextColumn get aiTags => text().nullable()();
  TextColumn get filePaths => text().nullable()();
}

class KnowledgeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get contentMarkdown => text().withDefault(const Constant(''))();
  IntColumn get categoryId => integer().nullable().references(CategoryModels, #id, onDelete: KeyAction.setNull)();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get aiSummary => text().nullable()();
  TextColumn get aiTags => text().nullable()();
  TextColumn get filePaths => text().nullable()();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
}

class CategoryModels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get icon => text().withDefault(const Constant('folder'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class DiaryTags extends Table {
  IntColumn get diaryEntryId => integer().references(DiaryEntries, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {diaryEntryId, tagId};
}

class KnowledgeTags extends Table {
  IntColumn get knowledgeEntryId => integer().references(KnowledgeEntries, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {knowledgeEntryId, tagId};
}

class AgentMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().withLength(min: 1, max: 100)();
  TextColumn get role => text().withLength(min: 1, max: 20)();
  TextColumn get content => text()();
  TextColumn get toolName => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    DiaryEntries,
    KnowledgeEntries,
    Tags,
    CategoryModels,
    DiaryTags,
    KnowledgeTags,
    AgentMessages,
    SettingsTable,
  ],
  daos: [DiaryDao, KnowledgeDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode=WAL');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(agentMessages);
          }
        },
        onCreate: (m) async {
          await m.createAll();
          // FTS5 虚拟表
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
              title, body, source_type, source_id
            )
          ''');
          // FTS5 自动同步触发器 - 日记
          // rowid 编码: diary=(source_id*2+1), knowledge=(source_id*2)
          // 永远不会冲突（奇偶分离）
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS diary_fts_insert AFTER INSERT ON diary_entries BEGIN
              INSERT INTO search_index(rowid, title, body, source_type, source_id)
              VALUES (new.id * 2 + 1, new.title, new.body_markdown, 'diary', new.id);
            END
          ''');
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS diary_fts_update AFTER UPDATE ON diary_entries BEGIN
              UPDATE search_index SET title = new.title, body = new.body_markdown,
              rowid = new.id * 2 + 1
              WHERE source_type = 'diary' AND source_id = old.id;
            END
          ''');
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS diary_fts_delete AFTER DELETE ON diary_entries BEGIN
              DELETE FROM search_index WHERE source_type = 'diary' AND source_id = old.id;
            END
          ''');
          // FTS5 自动同步触发器 - 知识
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS knowledge_fts_insert AFTER INSERT ON knowledge_entries BEGIN
              INSERT INTO search_index(rowid, title, body, source_type, source_id)
              VALUES (new.id * 2, new.title, new.content_markdown, 'knowledge', new.id);
            END
          ''');
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS knowledge_fts_update AFTER UPDATE ON knowledge_entries BEGIN
              UPDATE search_index SET title = new.title, body = new.content_markdown,
              rowid = new.id * 2
              WHERE source_type = 'knowledge' AND source_id = old.id;
            END
          ''');
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS knowledge_fts_delete AFTER DELETE ON knowledge_entries BEGIN
              DELETE FROM search_index WHERE source_type = 'knowledge' AND source_id = old.id;
            END
          ''');
          // 预设分类
          await customStatement(
            "INSERT INTO category_models (name, icon, sort_order) VALUES "
            "('技术开发', 'code', 0),"
            "('产品设计', 'design_services', 1),"
            "('AI & 机器学习', 'psychology', 2),"
            "('设计 & 体验', 'palette', 3),"
            "('阅读笔记', 'menu_book', 4),"
            "('工具 & 效率', 'build', 5)",
          );
        },
      );

  /// 带锁重试保护的写入操作。
  /// 用于 Agent 多轮同时写 agent_messages 等并发场景。
  Future<T> runWithRetry<T>(Future<T> Function() operation) =>
      retryOnLock(operation);

  // FTS5 全文搜索
  Future<List<Map<String, Object?>>> search(String query) async {
    // 移除 FTS5 特殊字符防止语法注入
    final sanitized = query.replaceAll(RegExp(r'[\^\*"\(\)]'), ' ');
    final terms = sanitized.split(' ').where((t) => t.trim().isNotEmpty).map((t) => '"$t"*').join(' ');
    if (terms.isEmpty) return [];
    final rows = await customSelect(
      'SELECT rowid, title, body, source_type, source_id '
      'FROM search_index WHERE search_index MATCH ? '
      'ORDER BY rank LIMIT 50',
      variables: [Variable.withString(terms)],
    ).get();
    return rows.map((r) => Map<String, Object?>.from(r.data)).toList();
  }
}

// 数据库初始化
Future<AppDatabase> _initDatabase() async {
  applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  final dbPath = p.join(
    (await getApplicationDocumentsDirectory()).path,
    'zhiji.db',
  );
  return AppDatabase(NativeDatabase(File(dbPath)));
}

final databaseProvider = FutureProvider<AppDatabase>((ref) => _initDatabase());
