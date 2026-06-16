import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio HTTP 客户端单例
/// 为 DeepSeek API 调用提供统一拦截器链
class AppDio {
  AppDio._();

  static Dio? _instance;

  static Dio get instance {
    if (_instance != null) return _instance!;

    _instance = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 日志拦截器（仅 debug 模式，不记录 header 防止 API Key 泄露）
    if (kDebugMode) {
      _instance!.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ));
    }

    return _instance!;
  }

  /// 设置 DeepSeek API Key（全局注入）
  static void setApiKey(String apiKey) {
    instance.options.headers['Authorization'] = 'Bearer $apiKey';
  }
}
