import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/custom_toast.dart';
import '../widgets/image_viewer.dart';
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
      CustomToast.show(
        context,
        message: _isEdit ? '文章已更新' : '文章已创建',
        type: ToastType.success,
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
        CustomToast.show(
          context,
          message: '文章已删除',
          type: ToastType.success,
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
      resizeToAvoidBottomInset: true,
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
      child: SingleChildScrollView(
        controller: _previewScrollController,
        padding: const EdgeInsets.all(16),
        child: _MarkdownPreview(content: _contentController.text),
      ),
    );
  }
}

/// 自定义 Markdown 预览组件（支持代码高亮）
class _MarkdownPreview extends StatelessWidget {
  final String content;
  
  const _MarkdownPreview({required this.content});
  
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
    
    // 使用正则匹配代码块 - 支持各种格式
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
    
    // 调试信息
    print('_CodeBlockView - 原始语言: "$language", 规范化后: "$normalizedLanguage"');
    print('_CodeBlockView - 代码内容: "${code.substring(0, code.length > 50 ? 50 : code.length)}..."');
    
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
