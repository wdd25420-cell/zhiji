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
    // 与 bing-cn-mcp 的 cheerio 解析逻辑完全一致
    // 必应搜索结果: <li class="b_algo"> $('h2 a') → title/url, $('.b_caption p') → snippet
    final blocks = html.split('<li class="b_algo"');
    for (var i = 1; i < blocks.length && items.length < count; i++) {
      final block = blocks[i];

      // 标题 & URL: 等价于 $('h2 a')
      final h2 = _between(block, '<h2', '</h2>');  // <h2 class="..."> 有属性
      if (h2.isEmpty) continue;
      final aHref = _attr(h2, 'href');
      final aText = _stripHtml(_between(h2, '<a', '</a>'));
      if (aText.isEmpty) continue;

      // 摘要: 等价于 $('.b_caption p').first()
      final caption = _between(block, 'class="b_caption', '</div>');
      final snippet = _stripHtml(_between(caption, '<p', '</p>'));

      items.add(WebSearchItem(title: aText, url: aHref, snippet: snippet));
    }
  } catch (e) {
    debugPrint("[bing_parse] $e");
  }
  return items.isEmpty ? const WebSearchResult(items: []) : WebSearchResult(items: items);
}

/// 提取两个标记之间的内容（不含标记自身）
String _between(String src, String start, String end) {
  final si = src.indexOf(start);
  if (si < 0) return '';
  final ei = src.indexOf(end, si + start.length);
  if (ei < 0) return '';
  return src.substring(si + start.length, ei);
}

/// 提取 HTML 标签的属性值
String _attr(String src, String attr) {
  final re = RegExp('$attr\\s*=\\s*"([^"]*)"');
  final m = re.firstMatch(src);
  return m?.group(1) ?? '';
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
