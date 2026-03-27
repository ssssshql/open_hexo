import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../models/article.dart';

class HexoService {
  /// 从 YAML 节点解析字符串列表
  List<String> _parseYamlList(dynamic value) {
    if (value == null) return [];
    
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    
    // 如果是单个字符串，包装成列表
    if (value is String) {
      return [value];
    }
    
    return [];
  }

  Future<List<Article>> loadArticles(String repoPath) async {
    final articles = <Article>[];
    final sourcePath = p.join(repoPath, 'source', '_posts');
    final postsDir = Directory(sourcePath);

    if (!await postsDir.exists()) {
      return articles;
    }

    await for (final entity in postsDir.list()) {
      if (entity is File && entity.path.endsWith('.md')) {
        try {
          final article = await _parseArticle(entity);
          articles.add(article);
        } catch (e) {
          // 忽略解析失败的文件
        }
      }
    }

    // 按日期倒序排序
    articles.sort((a, b) => b.date.compareTo(a.date));
    return articles;
  }

  Future<Article> _parseArticle(File file) async {
    final content = await file.readAsString();
    final frontMatterEnd = content.indexOf('---', 3);
    
    if (frontMatterEnd == -1) {
      return Article(
        title: p.basenameWithoutExtension(file.path),
        date: DateTime.now().toIso8601String(),
        content: content,
        filePath: file.path,
      );
    }

    final frontMatter = content.substring(3, frontMatterEnd);
    final body = content.substring(frontMatterEnd + 3).trim();
    
    final yaml = loadYaml(frontMatter);
    
    return Article(
      title: yaml['title']?.toString() ?? p.basenameWithoutExtension(file.path),
      date: yaml['date']?.toString() ?? DateTime.now().toIso8601String(),
      tags: _parseYamlList(yaml['tags']),
      categories: _parseYamlList(yaml['categories']),
      content: body,
      filePath: file.path,
    );
  }

  Future<String> createArticle(String repoPath, Article article) async {
    final sourcePath = p.join(repoPath, 'source', '_posts');
    final postsDir = Directory(sourcePath);

    if (!await postsDir.exists()) {
      await postsDir.create(recursive: true);
    }

    final fileName = _sanitizeFileName(article.title);
    final filePath = p.join(sourcePath, '$fileName.md');
    final file = File(filePath);

    final content = _generateFrontMatter(article);
    await file.writeAsString(content);

    // 确保文件已写入磁盘（Android 文件系统缓存）
    await file.lastModified();

    return filePath;
  }

  Future<void> updateArticle(Article article) async {
    final file = File(article.filePath);
    if (!await file.exists()) return;
    
    final content = _generateFrontMatter(article);
    await file.writeAsString(content);
    
    // 确保文件已写入磁盘（Android 文件系统缓存）
    await file.lastModified();
  }

  Future<void> deleteArticle(Article article) async {
    final file = File(article.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _generateFrontMatter(Article article) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('title: ${article.title}');
    buffer.writeln('date: ${article.date}');
    
    if (article.tags.isNotEmpty) {
      buffer.writeln('tags:');
      for (final tag in article.tags) {
        buffer.writeln('  - $tag');
      }
    }
    
    if (article.categories.isNotEmpty) {
      buffer.writeln('categories:');
      for (final category in article.categories) {
        buffer.writeln('  - $category');
      }
    }
    
    buffer.writeln('---');
    buffer.writeln();
    buffer.write(article.content);
    
    return buffer.toString();
  }

  String _sanitizeFileName(String title) {
    // 保留中文、字母、数字、空格、连字符、下划线
    var sanitized = title
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fa5-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase();
    
    // 如果结果为空，使用时间戳
    if (sanitized.isEmpty) {
      sanitized = DateTime.now().millisecondsSinceEpoch.toString();
    }
    
    return sanitized;
  }
}
