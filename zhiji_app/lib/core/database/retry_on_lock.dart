import "package:flutter/foundation.dart";

/// 在数据库写入遭遇锁时自动重试，最多 [maxRetries] 次。
/// 仅对 "database is locked" 错误重试，其他异常原样抛出。
///
/// 使用指数退避：100ms → 200ms → 400ms（上限 500ms）。
Future<T> retryOnLock<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
}) async {
  var attempt = 0;
  while (true) {
    try {
      return await operation();
    } on Exception catch (e) {
      if (!e.toString().contains("database is locked") ||
          attempt >= maxRetries) {
        rethrow;
      }
      attempt++;
      final delay = 100 * (1 << (attempt - 1)).clamp(1, 5);
      debugPrint("[DB] 写入锁冲突，第 $attempt 次重试，等待 ${delay}ms…");
      await Future.delayed(Duration(milliseconds: delay));
    }
  }
}
