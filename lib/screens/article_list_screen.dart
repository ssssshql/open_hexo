import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' as highlight;
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/article.dart';
import 'article_edit_screen.dart';

class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文章列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AppState>().loadArticles(),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (appState.articles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '暂无文章',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮创建新文章',
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
              itemCount: appState.articles.length,
              itemBuilder: (context, index) {
                final article = appState.articles[index];
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
            body: Markdown(
              data: article.content,
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              styleSheet: MarkdownStyleSheet(
                // 行内代码样式 - 简洁风格
                code: TextStyle(
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.red.shade700,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                // 代码块样式
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                codeblockPadding: const EdgeInsets.all(16),
              ),
              builders: {
                'code': _CodeBlockBuilder(),
              },
            ),
          );
        },
      ),
    );
  }
}

/// 自定义代码块渲染器（仅处理多行代码块）
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, preferredStyle) {
    if (element.textContent.isEmpty) return const SizedBox.shrink();
    
    // 检查是否是代码块（包含换行符）
    if (!element.textContent.contains('\n')) {
      // 行内代码，返回 null 使用默认样式
      return null;
    }
    
    String language = 'plaintext';
    String code = element.textContent;
    
    // 尝试从代码块提取语言标识
    if (element.attributes.isNotEmpty) {
      final className = element.attributes['class'] ?? '';
      if (className.startsWith('language-')) {
        language = className.substring(9);
      }
    }
    
    // 代码块高亮
    return _CodeBlockWidget(code: code, language: language);
  }
}

/// 代码块 Widget
class _CodeBlockWidget extends StatelessWidget {
  final String code;
  final String language;

  const _CodeBlockWidget({
    required this.code,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  language.toUpperCase(),
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
          // 代码内容
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: _HighlightedCode(code: code, language: language),
          ),
        ],
      ),
    );
  }
}

/// 高亮代码显示（VS Code 风格配色）
class _HighlightedCode extends StatelessWidget {
  final String code;
  final String language;

  const _HighlightedCode({
    required this.code,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final result = highlight.highlight.parse(code, language: language);
      
      return RichText(
        text: TextSpan(
          children: result.nodes!.map((node) => _buildTextSpan(node)).toList(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFFD4D4D4),
          ),
        ),
      );
    } catch (e) {
      return Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFD4D4D4),
        ),
      );
    }
  }

  TextSpan _buildTextSpan(highlight.Node node) {
    final color = _getColor(node.className);
    final style = TextStyle(
      color: color,
      fontFamily: 'monospace',
      fontSize: 13,
    );

    if (node.value != null) {
      return TextSpan(text: node.value, style: style);
    }

    return TextSpan(
      children: node.children!.map((child) => _buildTextSpan(child)).toList(),
      style: style,
    );
  }

  // VS Code Dark+ 主题配色
  Color _getColor(String? className) {
    switch (className) {
      case 'keyword':
        return const Color(0xFF569CD6); // 蓝色
      case 'built_in':
        return const Color(0xFF4EC9B0); // 青色
      case 'string':
        return const Color(0xFFCE9178); // 橙色
      case 'number':
        return const Color(0xFFB5CEA8); // 浅绿色
      case 'comment':
        return const Color(0xFF6A9955); // 绿色
      case 'function':
        return const Color(0xFFDCDCAA); // 黄色
      case 'title':
        return const Color(0xFF9CDCFE); // 浅蓝色
      case 'params':
        return const Color(0xFF9CDCFE);
      case 'class':
        return const Color(0xFF4EC9B0);
      case 'variable':
        return const Color(0xFF9CDCFE);
      case 'symbol':
        return const Color(0xFFB5CEA8);
      case 'attr':
        return const Color(0xFF9CDCFE);
      case 'literal':
        return const Color(0xFF569CD6);
      case 'meta':
        return const Color(0xFF808080);
      case 'type':
        return const Color(0xFF4EC9B0);
      default:
        return const Color(0xFFD4D4D4);
    }
  }
}
