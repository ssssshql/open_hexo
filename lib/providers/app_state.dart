import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/repo_config.dart';
import '../models/article.dart';
import '../services/config_service.dart';
import '../services/git_service.dart';
import '../services/hexo_service.dart';
import '../services/logger_service.dart';

class AppState extends ChangeNotifier {
  final ConfigService _configService = ConfigService();
  final GitService _gitService = GitService();
  final HexoService _hexoService = HexoService();
  final LoggerService _logger = LoggerService();

  RepoConfig? _config;
  List<Article> _articles = [];
  bool _isLoading = false;
  String _statusMessage = '';
  String? _errorMessage;

  RepoConfig? get config => _config;
  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => _config != null && _config!.repoUrl.isNotEmpty;

  Future<void> loadConfig() async {
    _config = await _configService.loadConfig();
    notifyListeners();
  }

  Future<void> saveConfig(RepoConfig config) async {
    // Android 使用应用私有目录，不需要权限
    final appDir = await getApplicationDocumentsDirectory();
    final localPath = p.join(appDir.path, 'hexo_blog');
    
    final finalConfig = config.copyWith(localPath: localPath);
    
    await _configService.saveConfig(finalConfig);
    _config = finalConfig;
    notifyListeners();
  }

  Future<void> clearConfig() async {
    await _configService.clearConfig();
    _config = null;
    _articles = [];
    notifyListeners();
  }

  Future<void> initDefaultPath() async {
    // 不再需要，路径会自动设置
  }

  Future<bool> cloneRepo() async {
    if (_config == null) return false;

    _logger.info('AppState', '开始克隆仓库');
    _setLoading(true, '正在克隆仓库...');
    
    final error = await _gitService.cloneRepo(
      _config!,
      onProgress: (msg) => _updateStatus(msg),
    );

    if (error != null) {
      _logger.error('AppState', '克隆仓库失败', error);
      _setError(error);
      return false;
    }

    _logger.info('AppState', '克隆仓库成功');
    _setLoading(false, '克隆完成');
    return true;
  }

  Future<bool> ensureRepoReady() async {
    if (_config == null) return false;

    // 检查仓库是否已存在
    final isCloned = await _gitService.isRepoCloned(_config!.localPath);
    
    if (!isCloned) {
      // 仓库不存在，执行克隆
      return await cloneRepo();
    }
    
    return true;
  }

  Future<bool> pullRepo() async {
    if (_config == null) return false;

    _setLoading(true, '正在拉取更新...');
    
    final error = await _gitService.pullRepo(
      _config!,
      onProgress: (msg) => _updateStatus(msg),
    );

    if (error != null) {
      _setError(error);
      return false;
    }

    await loadArticles();
    _setLoading(false, '拉取完成');
    return true;
  }

  Future<String?> previewCommitMessage() async {
    if (_config == null) return null;
    return await _gitService.previewCommitMessage(_config!.localPath);
  }

  Future<bool> pushRepo() async {
    if (_config == null) return false;

    _logger.info('AppState', '开始推送更新');
    _setLoading(true, '正在推送更新...');
    
    final error = await _gitService.pushRepo(
      _config!.localPath,
      _config!,
      onProgress: (msg) => _updateStatus(msg),
    );

    if (error != null) {
      _logger.error('AppState', '推送失败', error);
      _setError(error);
      return false;
    }

    _logger.info('AppState', '推送成功');
    _setLoading(false, '推送完成');
    return true;
  }

  Future<void> loadArticles() async {
    if (_config == null) return;

    _logger.debug('AppState', '加载文章列表');
    _setLoading(true, '正在加载文章...');
    
    try {
      _articles = await _hexoService.loadArticles(_config!.localPath);
      _logger.info('AppState', '加载了 ${_articles.length} 篇文章');
      _setLoading(false, '加载完成');
    } catch (e, stackTrace) {
      _logger.error('AppState', '加载文章失败', e, stackTrace);
      _setError('加载文章失败: $e');
    }
  }

  Future<bool> createArticle(Article article) async {
    if (_config == null) return false;

    _logger.info('AppState', '创建文章: ${article.title}');
    try {
      await _hexoService.createArticle(_config!.localPath, article);
      await loadArticles();
      _logger.info('AppState', '文章创建成功');
      return true;
    } catch (e, stackTrace) {
      _logger.error('AppState', '创建文章失败', e, stackTrace);
      _setError('创建文章失败: $e');
      return false;
    }
  }

  Future<bool> updateArticle(Article article) async {
    _logger.info('AppState', '更新文章: ${article.title}');
    try {
      await _hexoService.updateArticle(article);
      await loadArticles();
      _logger.info('AppState', '文章更新成功');
      return true;
    } catch (e, stackTrace) {
      _logger.error('AppState', '更新文章失败', e, stackTrace);
      _setError('更新文章失败: $e');
      return false;
    }
  }

  Future<bool> deleteArticle(Article article) async {
    _logger.info('AppState', '删除文章: ${article.title}');
    try {
      await _hexoService.deleteArticle(article);
      await loadArticles();
      _logger.info('AppState', '文章删除成功');
      return true;
    } catch (e, stackTrace) {
      _logger.error('AppState', '删除文章失败', e, stackTrace);
      _setError('删除文章失败: $e');
      return false;
    }
  }

  void _setLoading(bool loading, String message) {
    _isLoading = loading;
    _statusMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  void _updateStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  void _setError(String error) {
    _isLoading = false;
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
