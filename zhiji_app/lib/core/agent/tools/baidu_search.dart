import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "../../network/dio_client.dart";
import "web_search.dart";

/// 百度搜索（网页抓取），无需 API Key，免费无限使用
///
/// 发送 GET 请求到 www.baidu.com，解析返回的 HTML 提取标题/网址/摘要。
Future<WebSearchResult> baiduSearch(
  String query, {
  int count = 5,
}) async {
  final dio = AppDio.instance;
  try {
    final response = await dio.get(
      "https://www.baidu.com/s",
      queryParameters: {
        "wd": query,
        "rn": count.clamp(1, 20).toString(),
        "ie": "utf-8",
      },
      options: Options(
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Mobile Safari/537.36",
          "Accept": "text/html,application/xhtml+xml",
          "Accept-Language": "zh-CN,zh;q=0.9",
        },
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.plain,
      ),
    );

    final html = response.data as String;
    return _parseBaidu(html, count);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const WebSearchResult(error: "联网搜索暂不可用，请检查网络");
    }
    debugPrint("[baidu_search] DioException: ${e.type} ${e.message}");
    return WebSearchResult(error: "搜索失败：${e.message}");
  } catch (e) {
    debugPrint("[baidu_search] 异常: $e");
    return const WebSearchResult(error: "搜索失败");
  }
}

WebSearchResult _parseBaidu(String html, int maxCount) {
  final items = <WebSearchItem>[];
  try {
    final blocks = html.split('class="result c-container');
    for (var i = 1; i < blocks.length && items.length < maxCount; i++) {
      final block = blocks[i];

      String title = "";
      final ti = block.indexOf('class="c-title');
      if (ti >= 0) {
        final as = block.indexOf('<a', ti);
        if (as >= 0) {
          title = _stripTags(block.substring(as, block.indexOf('</a>', as)));
        }
      }

      String snippet = "";
      final si = block.indexOf('class="c-summary');
      if (si >= 0) {
        final ds = block.indexOf('>', si) + 1;
        if (ds > 0) snippet = _stripTags(block.substring(ds, block.indexOf('</div>', ds)));
      }

      String url = "";
      final ui = block.indexOf('class="c-showurl');
      if (ui >= 0) {
        url = _stripTags(block.substring(ui, block.indexOf('</span>', ui))).trim();
      }

      if (title.isNotEmpty) items.add(WebSearchItem(title: title, url: url, snippet: snippet));
    }
  } catch (e) {
    debugPrint("[baidu_search] 解析异常: $e");
  }
  return items.isEmpty ? const WebSearchResult(items: []) : WebSearchResult(items: items);
}

String _stripTags(String text) {
  return text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
