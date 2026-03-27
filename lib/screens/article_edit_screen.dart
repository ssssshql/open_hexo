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
  final String? heroTag;

  const ArticleEditScreen({super.key, this.article, this.heroTag});

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
      final success = await context.read<AppState>().deleteArticle(
        widget.article!,
      );
      if (success && mounted) {
        Navigator.pop(context);
        CustomToast.show(context, message: '文章已删除', type: ToastType.success);
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

  void _showEditMetaDialog(BuildContext context) {
    final titleController = TextEditingController(text: _titleController.text);
    final tagsController = TextEditingController(text: _tagsController.text);
    final categoriesController = TextEditingController(text: _categoriesController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑文章信息'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '文章标题 *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: '标签',
                  hintText: '逗号分隔',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoriesController,
                decoration: const InputDecoration(
                  labelText: '分类',
                  hintText: '逗号分隔',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _titleController.text = titleController.text;
                _tagsController.text = tagsController.text;
                _categoriesController.text = categoriesController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _getArticleIcon() {
    final tags = _tagsController.text.split(',').map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList();
    final categories = _categoriesController.text.split(',').map((c) => c.trim().toLowerCase()).where((c) => c.isNotEmpty).toList();
    final allKeywords = [...tags, ...categories];
    final content = _contentController.text.toLowerCase();

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

  @override
  Widget build(BuildContext context) {
    final (iconData, iconColor) = _getArticleIcon();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // 固定标题栏
            Material(
              color: colorScheme.surface,
              elevation: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
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
                      const SizedBox(width: 8),
                      // Hero区域
                      if (widget.heroTag != null)
                        Hero(
                          tag: widget.heroTag!,
                          child: Material(
                            color: iconColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(iconData, size: 20, color: iconColor),
                            ),
                          ),
                        )
                      else
                        Material(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(iconData, size: 20, color: iconColor),
                          ),
                        ),
                      const SizedBox(width: 10),
                      // 标题和日期
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _titleController.text.isEmpty ? '新文章' : _titleController.text,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 3),
                                Text(
                                  widget.article?.date.split('T').first ?? DateTime.now().toIso8601String().split('T').first,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 操作按钮 - 更紧凑
                      if (_isEdit)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red,
                          onPressed: _deleteArticle,
                          tooltip: '删除',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                        ),
                      IconButton(
                        icon: Icon(_isPreview ? Icons.edit_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setState(() => _isPreview = !_isPreview),
                        tooltip: _isPreview ? '编辑' : '预览',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save_outlined, size: 20),
                        onPressed: _saveArticle,
                        tooltip: '保存',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 元信息区域（点击编辑）
            InkWell(
              onTap: () => _showEditMetaDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, size: 18, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleController.text.isEmpty ? '点击设置标题...' : _titleController.text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _titleController.text.isEmpty ? Colors.grey : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (_tagsController.text.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    '标签: ${_tagsController.text}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (_categoriesController.text.isNotEmpty) ...[
                                if (_tagsController.text.isNotEmpty)
                                  Text(' · ', style: TextStyle(color: Colors.grey.shade400)),
                                Expanded(
                                  child: Text(
                                    '分类: ${_categoriesController.text}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (_tagsController.text.isEmpty && _categoriesController.text.isEmpty)
                                Text(
                                  '点击设置标签、分类...',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // 编辑区域
            Expanded(
              child: _isPreview
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _MarkdownPreview(content: _contentController.text),
                      ),
                    )
                  : TextField(
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
            ),
            // 底部工具栏
            if (!_isPreview)
              Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
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
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
    final codeBlockRegex = RegExp(
      r'```([a-zA-Z0-9+_-]*)\s*\n([\s\S]*?)\n?```',
      multiLine: true,
    );

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
              imageBuilder: (uri, title, alt) =>
                  _buildImageWithPlaceholder(context, uri),
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
            imageBuilder: (uri, title, alt) =>
                _buildImageWithPlaceholder(context, uri),
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
                      style: TextStyle(color: Color(0xFF757575), fontSize: 12),
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
                        Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
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

  const _CodeBlockView({required this.code, required this.language});

  @override
  Widget build(BuildContext context) {
    // 规范化语言名称
    final normalizedLanguage = _normalizeLanguage(language);

    // 调试信息
    print('_CodeBlockView - 原始语言: "$language", 规范化后: "$normalizedLanguage"');
    print(
      '_CodeBlockView - 代码内容: "${code.substring(0, code.length > 50 ? 50 : code.length)}..."',
    );

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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  normalizedLanguage.isNotEmpty
                      ? normalizedLanguage.toUpperCase()
                      : 'CODE',
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
              language: normalizedLanguage.isNotEmpty
                  ? normalizedLanguage
                  : 'plaintext',
              theme: vs2015Theme,
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
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
