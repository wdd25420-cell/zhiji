import "dart:convert";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "../../network/dio_client.dart";

/// 单条搜索结果
class WebSearchItem {
  final String title;
  final String url;
  final String snippet;
  const WebSearchItem({required this.title, required this.url, required this.snippet});
  Map<String, dynamic> toJson() => {"title": title, "url": url, "snippet": snippet};
}

/// 搜索结果容器
class WebSearchResult {
  final List<WebSearchItem> items;
  final String? error;
  const WebSearchResult({this.items = const [], this.error});
  bool get isError => error != null;
}

/// 必应搜索——cn.bing.com，国内可用，免费无需 Key
///
/// 直接抓取必应中文版搜索结果页 HTML 并解析。
/// 参考开源项目 bing-cn-mcp。
Future<WebSearchResult> webSearch(String query, {int count = 5}) async {
  final dio = AppDio.instance;
  try {
    final response = await dio.get(
      "https://cn.bing.com/search",
      queryParameters: {"q": query, "first": 1},
      options: Options(
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Accept": "text/html,application/xhtml+xml",
          "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        },
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.plain,
      ),
    );

    final html = response.data is List<int>
        ? utf8.decode(response.data as List<int>)
        : response.data as String;
    debugPrint("[bing_search] HTML长度: ${html.length}");
    return _parseBing(html, count);
  } on DioException catch (e) {
    debugPrint("[bing_search] ${e.type} HTTP${e.response?.statusCode}");
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const WebSearchResult(error: "联网搜索暂不可用，请检查网络");
    }
    return WebSearchResult(error: "搜索失败");
  } catch (e) {
    debugPrint("[bing_search] $e");
    return const WebSearchResult(error: "搜索失败");
  }
}

WebSearchResult _parseBing(String html, int count) {
  final items = <WebSearchItem>[];
  try {
    // 必应搜索结果结构: <li class="b_algo"> 包含标题、摘要、URL
    final blocks = html.split('<li class="b_algo"');
    for (var i = 1; i < blocks.length && items.length < count; i++) {
      final block = blocks[i];

      // 标题: <h2><a href="...">标题</a></h2>
      String title = "";
      final h2Start = block.indexOf('<h2>');
      if (h2Start >= 0) {
        final aStart = block.indexOf('<a', h2Start);
        if (aStart >= 0) {
          final aEnd = block.indexOf('</a>', aStart);
          if (aEnd >= 0) {
            title = _stripHtml(block.substring(aStart, aEnd));
          }
        }
      }

      // URL: <a href="..."> 中的链接
      String url = "";
      final urlStart = block.indexOf('href="http');
      if (urlStart >= 0) {
        final urlEnd = block.indexOf('"', urlStart + 6);
        if (urlEnd >= 0) url = block.substring(urlStart + 6, urlEnd);
      }

      // 摘要: <p> 或 <div class="b_caption">
      String snippet = "";
      for (final cls in ['b_caption"', 'b_lineclamp', 'b_algoSlug']) {
        final snip = RegExp('class="$cls[^"]*"[^>]*>(.+?)</(?:div|p)>', dotAll: true).firstMatch(block);
        if (snip != null) {
          snippet = _stripHtml(snip.group(1)!);
          break;
        }
      }
      // fallback: 取第一个 <p>
      if (snippet.isEmpty) {
        final pMatch = RegExp(r'<p[^>]*>(.+?)</p>', dotAll: true).firstMatch(block);
        if (pMatch != null) snippet = _stripHtml(pMatch.group(1)!);
      }

      if (title.isNotEmpty) {
        items.add(WebSearchItem(title: title, url: url, snippet: snippet));
      }
    }
  } catch (e) {
    debugPrint("[bing_parse] $e");
  }
  return items.isEmpty ? const WebSearchResult(items: []) : WebSearchResult(items: items);
}

String _stripHtml(String text) {
  return text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', '\'')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
