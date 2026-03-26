import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' as highlight;
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/article.dart';

class ArticleEditScreen extends StatefulWidget {
  final Article? article;

  const ArticleEditScreen({super.key, this.article});

  @override
  State<ArticleEditScreen> createState() => _ArticleEditScreenState();
}

class _ArticleEditScreenState extends State<ArticleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _tagsController;
  late TextEditingController _categoriesController;
  late TextEditingController _contentController;
  late ScrollController _editorScrollController;
  late ScrollController _previewScrollController;
  bool _isEdit = false;
  bool _isPreview = false; // false: 编辑, true: 预览
  
  @override
  void initState() {
    super.initState();
    _isEdit = widget.article != null;
    _titleController = TextEditingController(text: widget.article?.title ?? '');
    _tagsController = TextEditingController(
      text: widget.article?.tags.join(', ') ?? '',
    );
    _categoriesController = TextEditingController(
      text: widget.article?.categories.join(', ') ?? '',
    );
    _contentController = TextEditingController(
      text: widget.article?.content ?? '',
    );
    _editorScrollController = ScrollController();
    _previewScrollController = ScrollController();
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _categoriesController.dispose();
    _contentController.dispose();
    _editorScrollController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  Future<void> _saveArticle() async {
    if (!_formKey.currentState!.validate()) return;

    final article = Article(
      title: _titleController.text.trim(),
      date: widget.article?.date ?? DateTime.now().toIso8601String(),
      tags: _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      categories: _categoriesController.text
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList(),
      content: _contentController.text,
      filePath: widget.article?.filePath ?? '',
    );

    final appState = context.read<AppState>();
    bool success;
    
    if (_isEdit) {
      success = await appState.updateArticle(article);
    } else {
      success = await appState.createArticle(article);
    }

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? '文章已更新' : '文章已创建')),
      );
    }
  }

  Future<void> _deleteArticle() async {
    if (!_isEdit || widget.article == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这篇文章吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<AppState>().deleteArticle(widget.article!);
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文章已删除')),
        );
      }
    }
  }

  void _insertCodeBlock() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final selectedText = selection.textInside(text);
    
    final codeBlock = '```\n$selectedText\n```';
    
    _contentController.text = text.replaceRange(
      selection.start,
      selection.end,
      codeBlock,
    );
    
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + 4,
    );
  }

  void _insertHeading() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final selectedText = selection.textInside(text);
    
    final heading = '## $selectedText';
    
    _contentController.text = text.replaceRange(
      selection.start,
      selection.end,
      heading,
    );
    
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + 3,
    );
  }

  void _insertBold() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final selectedText = selection.textInside(text);
    
    final bold = '**$selectedText**';
    
    _contentController.text = text.replaceRange(
      selection.start,
      selection.end,
      bold,
    );
    
    if (selectedText.isEmpty) {
      _contentController.selection = TextSelection.collapsed(
        offset: selection.start + 2,
      );
    }
  }

  void _insertLink() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final selectedText = selection.textInside(text);
    
    final link = '[$selectedText](url)';
    
    _contentController.text = text.replaceRange(
      selection.start,
      selection.end,
      link,
    );
    
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + link.length - 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑文章' : '新建文章'),
        actions: [
          // 编辑/预览切换
          IconButton(
            icon: Icon(_isPreview ? Icons.edit : Icons.visibility),
            onPressed: () => setState(() => _isPreview = !_isPreview),
            tooltip: _isPreview ? '编辑' : '预览',
          ),
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteArticle,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveArticle,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // 标题、标签、分类区域
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      label: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '文章标题 ', style: TextStyle(color: Colors.grey.shade700)),
                            const TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入标题';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tagsController,
                          decoration: const InputDecoration(
                            labelText: '标签',
                            hintText: '逗号分隔',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _categoriesController,
                          decoration: const InputDecoration(
                            labelText: '分类',
                            hintText: '逗号分隔',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 内容区域
            Expanded(
              child: _isPreview ? _buildPreview() : _buildEditor(),
            ),
          ],
        ),
      ),
      // 底部工具栏
      bottomNavigationBar: !_isPreview
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: SafeArea(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.title),
                        onPressed: _insertHeading,
                        tooltip: '标题',
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_bold),
                        onPressed: _insertBold,
                        tooltip: '粗体',
                      ),
                      IconButton(
                        icon: const Icon(Icons.code),
                        onPressed: _insertCodeBlock,
                        tooltip: '代码块',
                      ),
                      IconButton(
                        icon: const Icon(Icons.link),
                        onPressed: _insertLink,
                        tooltip: '链接',
                      ),
                      const Spacer(),
                      Text(
                        '${_contentController.text.length}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEditor() {
    return Container(
      color: Colors.grey.shade50,
      child: TextField(
        controller: _contentController,
        scrollController: _editorScrollController,
        decoration: const InputDecoration(
          hintText: '在此输入 Markdown 内容...',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      color: Colors.white,
      child: Markdown(
        data: _contentController.text,
        controller: _previewScrollController,
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

/// 高亮代码显示（VS Code Dark+ 主题配色）
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
