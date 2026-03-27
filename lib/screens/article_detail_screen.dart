import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import '../models/article.dart';
import '../widgets/image_viewer.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  final String heroTag;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final (iconData, iconColor) = _getArticleIcon();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // 固定标题栏
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 返回按钮
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, size: 20, color: Colors.grey.shade700),
                        tooltip: '返回',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Hero区域
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Hero(
                            tag: heroTag,
                            child: Material(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(iconData, size: 20, color: iconColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  article.title,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      article.date.split('T').first,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 可滚动内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: article.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _MarkdownPreviewWithHighlight(content: article.content),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 根据文章标签或内容获取图标
  (IconData, Color) _getArticleIcon() {
    final tags = article.tags.map((t) => t.toLowerCase()).toList();
    final categories = article.categories.map((c) => c.toLowerCase()).toList();
    final allKeywords = [...tags, ...categories];
    final content = article.content.toLowerCase();

    // 技术相关
    if (allKeywords.any((k) => ['代码', 'code', '编程', 'programming', '开发', 'development'].contains(k))) {
      return (Icons.code, const Color(0xFF6B7280));
    }
    if (allKeywords.any((k) => ['flutter', 'dart'].contains(k))) {
      return (Icons.flutter_dash, const Color(0xFF02569B));
    }
    if (allKeywords.any((k) => ['前端', 'frontend', 'vue', 'react', 'angular'].contains(k))) {
      return (Icons.web, const Color(0xFF42B883));
    }
    if (allKeywords.any((k) => ['后端', 'backend', 'server', 'node', 'java', 'python'].contains(k))) {
      return (Icons.dns, const Color(0xFF3776AB));
    }
    if (allKeywords.any((k) => ['数据库', 'database', 'mysql', 'mongodb', 'sql'].contains(k))) {
      return (Icons.storage, const Color(0xFF00758F));
    }
    if (allKeywords.any((k) => ['git', 'github', '版本控制'].contains(k))) {
      return (Icons.source, const Color(0xFFF05032));
    }
    if (allKeywords.any((k) => ['docker', 'k8s', 'kubernetes', 'devops'].contains(k))) {
      return (Icons.cloud_queue, const Color(0xFF2496ED));
    }
    if (allKeywords.any((k) => ['ai', '人工智能', 'machine learning', '机器学习'].contains(k))) {
      return (Icons.psychology, const Color(0xFFFF6F00));
    }

    // 生活相关
    if (allKeywords.any((k) => ['生活', 'life', '日常', 'daily'].contains(k))) {
      return (Icons.local_cafe, const Color(0xFF8D6E63));
    }
    if (allKeywords.any((k) => ['旅行', 'travel', '旅游', '游记'].contains(k))) {
      return (Icons.flight, const Color(0xFF00ACC1));
    }
    if (allKeywords.any((k) => ['美食', 'food', '烹饪', 'cooking'].contains(k))) {
      return (Icons.restaurant, const Color(0xFFEF5350));
    }
    if (allKeywords.any((k) => ['音乐', 'music', '歌'].contains(k))) {
      return (Icons.music_note, const Color(0xFFAB47BC));
    }
    if (allKeywords.any((k) => ['电影', 'movie', '影视', '剧'].contains(k))) {
      return (Icons.movie, const Color(0xFFE91E63));
    }
    if (allKeywords.any((k) => ['读书', 'reading', '书评', 'book'].contains(k))) {
      return (Icons.book, const Color(0xFF795548));
    }
    if (allKeywords.any((k) => ['摄影', 'photo', '照片', 'photography'].contains(k))) {
      return (Icons.camera_alt, const Color(0xFF009688));
    }
    if (allKeywords.any((k) => ['游戏', 'game', 'gaming'].contains(k))) {
      return (Icons.sports_esports, const Color(0xFF9C27B0));
    }

    // 其他主题
    if (allKeywords.any((k) => ['教程', 'tutorial', '学习', 'learn'].contains(k))) {
      return (Icons.school, const Color(0xFF3F51B5));
    }
    if (allKeywords.any((k) => ['想法', 'idea', '思考', 'thinking'].contains(k))) {
      return (Icons.lightbulb_outline, const Color(0xFFFFC107));
    }
    if (allKeywords.any((k) => ['项目', 'project', '作品'].contains(k))) {
      return (Icons.work_outline, const Color(0xFF607D8B));
    }
    if (allKeywords.any((k) => ['总结', 'summary', '回顾', 'review'].contains(k))) {
      return (Icons.summarize, const Color(0xFF00BCD4));
    }

    // 根据内容判断
    if (content.contains('```') || content.contains('function') || content.contains('class ')) {
      return (Icons.code, const Color(0xFF6B7280));
    }

    // 默认图标
    return (Icons.article, const Color(0xFF5C6BC0));
  }
}

/// 支持代码高亮的 Markdown 预览
class _MarkdownPreviewWithHighlight extends StatelessWidget {
  final String content;
  
  const _MarkdownPreviewWithHighlight({required this.content});
  
  @override
  Widget build(BuildContext context) {
    final widgets = _parseMarkdown(context, content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
  
  List<Widget> _parseMarkdown(BuildContext context, String markdown) {
    final widgets = <Widget>[];
    
    // 使用正则匹配代码块
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9+_-]*)\s*\n([\s\S]*?)\n?```', multiLine: true);
    
    int lastEnd = 0;
    final matches = codeBlockRegex.allMatches(markdown);
    
    for (final match in matches) {
      // 添加代码块之前的普通 Markdown 内容
      if (match.start > lastEnd) {
        final normalContent = markdown.substring(lastEnd, match.start);
        if (normalContent.trim().isNotEmpty) {
          widgets.add(
            MarkdownBody(
              data: normalContent,
              imageBuilder: (uri, title, alt) => _buildImageWithPlaceholder(context, uri),
              styleSheet: MarkdownStyleSheet(
                code: TextStyle(
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.red.shade700,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
      }
      
      // 添加代码块
      final language = match.group(1)?.trim() ?? '';
      final code = match.group(2) ?? '';
      widgets.add(_CodeBlockView(code: code, language: language));
      
      lastEnd = match.end;
    }
    
    // 添加最后剩余的 Markdown 内容
    if (lastEnd < markdown.length) {
      final normalContent = markdown.substring(lastEnd);
      if (normalContent.trim().isNotEmpty) {
        widgets.add(
          MarkdownBody(
            data: normalContent,
            imageBuilder: (uri, title, alt) => _buildImageWithPlaceholder(context, uri),
            styleSheet: MarkdownStyleSheet(
              code: TextStyle(
                backgroundColor: Colors.grey.shade200,
                color: Colors.red.shade700,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
        );
      }
    }
    
    return widgets.isEmpty ? [const Text('')] : widgets;
  }
  
  Widget _buildImageWithPlaceholder(BuildContext context, Uri uri) {
    return GestureDetector(
      onTap: () => ImageViewer.show(context, uri.toString()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // 占位背景
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '加载中...',
                      style: TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 实际图片
            Positioned.fill(
              child: Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  // 加载完成前返回透明，让占位背景显示
                  if (loadingProgress != null) {
                    return const SizedBox.shrink();
                  }
                  return child;
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          '图片加载失败',
                          style: TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 代码块显示组件
class _CodeBlockView extends StatelessWidget {
  final String code;
  final String language;

  const _CodeBlockView({
    required this.code,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    // 规范化语言名称
    final normalizedLanguage = _normalizeLanguage(language);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 语言标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  normalizedLanguage.isNotEmpty ? normalizedLanguage.toUpperCase() : 'CODE',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // 代码高亮显示
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              code.trim(),
              language: normalizedLanguage.isNotEmpty ? normalizedLanguage : 'plaintext',
              theme: vs2015Theme,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 规范化语言名称，确保与 highlight 包兼容
  String _normalizeLanguage(String lang) {
    if (lang.isEmpty) return 'plaintext';
    
    // 常见语言别名映射
    final languageMap = {
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'rb': 'ruby',
      'sh': 'bash',
      'shell': 'bash',
      'yml': 'yaml',
      'md': 'markdown',
      'c++': 'cpp',
      'c#': 'csharp',
      'objective-c': 'objectivec',
      'vue': 'vue',
      'docker': 'dockerfile',
      'dockerfile': 'dockerfile',
    };
    
    final normalized = lang.toLowerCase().trim();
    return languageMap[normalized] ?? normalized;
  }
}
