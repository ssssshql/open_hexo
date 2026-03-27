import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/article.dart';
import 'article_edit_screen.dart';
import 'article_detail_screen.dart';

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDate;
  bool _isTimelineView = false; // 是否显示时间线视图

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCalendarDialog(AppState appState) async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => _CalendarDialog(
        articles: appState.articles,
        selectedDate: _selectedDate,
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedDate = selected;
      });
    }
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
            : _selectedDate != null
                ? Text('${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}')
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
          if (!_isSearching && _selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
              },
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
          if (!_isSearching)
            Consumer<AppState>(
              builder: (context, appState, child) {
                return IconButton(
                  icon: const Icon(Icons.calendar_today_outlined, weight: 600),
                  onPressed: () => _showCalendarDialog(appState),
                );
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: Icon(_isTimelineView ? Icons.view_list : Icons.timeline, weight: 600),
              tooltip: _isTimelineView ? '列表视图' : '时间线视图',
              onPressed: () {
                setState(() {
                  _isTimelineView = !_isTimelineView;
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

          // 根据搜索词和日期过滤文章
          var articles = appState.articles;
          
          if (_searchQuery.isNotEmpty) {
            articles = articles.where((article) =>
                article.title.toLowerCase().contains(_searchQuery)).toList();
          }
          
          if (_selectedDate != null) {
            articles = articles.where((article) {
              final articleDate = DateTime.parse(article.date.split('T').first);
              return articleDate.year == _selectedDate!.year &&
                     articleDate.month == _selectedDate!.month &&
                     articleDate.day == _selectedDate!.day;
            }).toList();
          }

          if (articles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty && _selectedDate == null ? '暂无文章' : '未找到匹配的文章',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isEmpty && _selectedDate == null ? '点击右下角按钮创建新文章' : '请尝试其他条件',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => appState.loadArticles(),
            child: _isTimelineView
                ? _buildTimelineView(articles)
                : _buildListView(articles),
          );
        },
      ),
    );
  }

  Widget _buildListView(List<Article> articles) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return _ArticleCard(article: article);
      },
    );
  }

  Widget _buildTimelineView(List<Article> articles) {
    // 按年月分组
    final groupedArticles = <String, List<Article>>{};
    for (final article in articles) {
      final dateStr = article.date.split('T').first;
      final parts = dateStr.split('-');
      final key = '${parts[0]}-${parts[1]}'; // YYYY-MM
      groupedArticles.putIfAbsent(key, () => []).add(article);
    }

    // 按时间倒序排序
    final sortedKeys = groupedArticles.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final monthArticles = groupedArticles[key]!;
        final parts = key.split('-');
        final year = parts[0];
        final month = int.parse(parts[1]);

        return _TimelineGroup(
          year: year,
          month: month,
          articles: monthArticles,
        );
      },
    );
  }
}

/// 日历选择对话框
class _CalendarDialog extends StatefulWidget {
  final List<Article> articles;
  final DateTime? selectedDate;

  const _CalendarDialog({
    required this.articles,
    this.selectedDate,
  });

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _currentMonth;
  late DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.selectedDate ?? DateTime.now();
    _selectedDate = widget.selectedDate;
  }

  Map<String, int> _getArticleCountByDate() {
    final countMap = <String, int>{};
    for (final article in widget.articles) {
      final dateKey = article.date.split('T').first;
      countMap[dateKey] = (countMap[dateKey] ?? 0) + 1;
    }
    return countMap;
  }

  @override
  Widget build(BuildContext context) {
    final articleCounts = _getArticleCountByDate();
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
              });
            },
          ),
          Text(
            '${_currentMonth.year}年${_currentMonth.month}月',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 星期标题
            Row(
              children: ['日', '一', '二', '三', '四', '五', '六'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // 日期网格
            _buildCalendarGrid(articleCounts, colorScheme),
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
            Navigator.pop(context, _selectedDate);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(Map<String, int> articleCounts, ColorScheme colorScheme) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday, 6 = Saturday

    final days = <Widget>[];

    // 填充空白
    for (var i = 0; i < startWeekday; i++) {
      days.add(const SizedBox());
    }

    // 填充日期
    for (var day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final count = articleCounts[dateKey] ?? 0;
      final isSelected = _selectedDate?.year == date.year &&
                         _selectedDate?.month == date.month &&
                         _selectedDate?.day == date.day;
      final isToday = DateTime.now().year == date.year &&
                      DateTime.now().month == date.month &&
                      DateTime.now().day == date.day;

      days.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 日期数字
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? colorScheme.onPrimaryContainer : null,
                  ),
                ),
                // 文章数量徽章 - 右上角
                if (count > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary : colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected ? colorScheme.onPrimary : colorScheme.onTertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // 今天标记
                if (isToday && !isSelected)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      mainAxisSpacing: 8,
      crossAxisSpacing: 4,
      childAspectRatio: 1.0,
      children: days,
    );
  }
}

/// 时间线分组组件
class _TimelineGroup extends StatelessWidget {
  final String year;
  final int month;
  final List<Article> articles;

  const _TimelineGroup({
    required this.year,
    required this.month,
    required this.articles,
  });

  static const _monthNames = [
    '', '一月', '二月', '三月', '四月', '五月', '六月',
    '七月', '八月', '九月', '十月', '十一月', '十二月'
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 年月标题
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 16, bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$year年${_monthNames[month]}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${articles.length}篇',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 文章列表
        ...articles.map((article) => _TimelineItem(article: article)),
      ],
    );
  }
}

/// 时间线单项组件
class _TimelineItem extends StatelessWidget {
  final Article article;

  const _TimelineItem({required this.article});

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (iconData, iconColor) = _getArticleIcon();
    final heroTag = 'article_${article.filePath}';
    
    // 解析日期和时间
    String day = '';
    String time = '';
    
    // 兼容两种日期格式: "2026-03-27T21:30:00" 和 "2026-03-27 21:30:00"
    if (article.date.contains('T')) {
      final parts = article.date.split('T');
      final datePart = parts.first; // 2026-03-27
      day = datePart.split('-').last; // 27
      if (parts.length > 1) {
        // 取时分秒部分，去掉毫秒
        time = parts.last.split('.').first.substring(0, 5); // 21:30
      }
    } else if (article.date.contains(' ')) {
      final parts = article.date.split(' ');
      final datePart = parts.first; // 2026-03-27
      day = datePart.split('-').last; // 27
      if (parts.length > 1) {
        // 取时分秒部分
        time = parts.last.substring(0, 5); // 21:30
      }
    } else {
      // 只有日期部分
      day = article.date.split('-').last;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间线圆点和连接线
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: Colors.grey.shade200,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // 文章卡片
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 300),
                      reverseTransitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return ArticleDetailScreen(article: article, heroTag: heroTag);
                      },
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Hero(
                        tag: heroTag,
                        child: Material(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(iconData, size: 20, color: iconColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  time.isNotEmpty ? '$day日 $time' : '$day日',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (article.tags.isNotEmpty)
                                  ...article.tags.take(3).map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 编辑按钮
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
                        tooltip: '编辑',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration: const Duration(milliseconds: 300),
                              reverseTransitionDuration: const Duration(milliseconds: 300),
                              pageBuilder: (context, animation, secondaryAnimation) {
                                return ArticleEditScreen(article: article, heroTag: heroTag);
                              },
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;

  const _ArticleCard({required this.article});

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (iconData, iconColor) = _getArticleIcon();
    final heroTag = 'article_${article.filePath}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showArticleDetail(context, heroTag),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              Builder(
                                builder: (context) {
                                  // 解析日期和时间
                                  String displayDate;
                                  if (article.date.contains('T')) {
                                    // 格式: 2026-03-27T21:30:00
                                    final parts = article.date.split('T');
                                    final datePart = parts.first;
                                    String timePart = '';
                                    if (parts.length > 1) {
                                      timePart = ' ${parts.last.split('.').first.substring(0, 5)}';
                                    }
                                    displayDate = '$datePart$timePart';
                                  } else if (article.date.contains(' ')) {
                                    // 格式: 2026-03-27 21:30:00
                                    final parts = article.date.split(' ');
                                    final datePart = parts.first;
                                    String timePart = '';
                                    if (parts.length > 1) {
                                      timePart = ' ${parts.last.substring(0, 5)}';
                                    }
                                    displayDate = '$datePart$timePart';
                                  } else {
                                    displayDate = article.date;
                                  }
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        displayDate,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 编辑按钮
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade700),
                      tooltip: '编辑',
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 300),
                            reverseTransitionDuration: const Duration(milliseconds: 300),
                            pageBuilder: (context, animation, secondaryAnimation) {
                              return ArticleEditScreen(article: article, heroTag: heroTag);
                            },
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              // 标签
              if (article.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: article.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              // 分隔线
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.grey.shade200, height: 1),
              ),
              
              // 内容预览
              Text(
                article.content.split('\n').first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showArticleDetail(BuildContext context, String heroTag) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ArticleDetailScreen(article: article, heroTag: heroTag);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
}
