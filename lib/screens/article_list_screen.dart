import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/article.dart';
import '../widgets/image_viewer.dart';
import 'article_edit_screen.dart';

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索文章标题...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : null,
        leading: IconButton(
          icon: Icon(_isSearching ? Icons.arrow_back : Icons.search, weight: 800),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                _isSearching = false;
                _searchController.clear();
                _searchQuery = '';
              } else {
                _isSearching = true;
              }
            });
          },
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.refresh, weight: 800),
              onPressed: () => context.read<AppState>().loadArticles(),
            ),
          if (_isSearching && _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 根据搜索词过滤文章
          final articles = _searchQuery.isEmpty
              ? appState.articles
              : appState.articles.where((article) =>
                  article.title.toLowerCase().contains(_searchQuery)).toList();

          if (articles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty ? '暂无文章' : '未找到匹配的文章',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isEmpty ? '点击右下角按钮创建新文章' : '请尝试其他关键词',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => appState.loadArticles(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                return _ArticleCard(article: article);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;

  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: () => _showArticleDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArticleEditScreen(article: article),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                article.date.split('T').first,
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (article.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: article.tags.map((tag) {
                    return Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                article.content.split('\n').first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showArticleDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Scaffold(
            appBar: AppBar(
              title: Text(article.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleEditScreen(article: article),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: _MarkdownPreviewWithHighlight(content: article.content),
            ),
          );
        },
      ),
    );
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
