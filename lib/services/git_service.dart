import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:git2dart/git2dart.dart';
import 'package:path/path.dart' as p;
import '../models/repo_config.dart';
import 'logger_service.dart';

/// Git 操作超时异常
class GitTimeoutException implements Exception {
  final String operation;
  final Duration timeout;
  
  GitTimeoutException(this.operation, this.timeout);
  
  @override
  String toString() => '操作 "$operation" 超时 (${timeout.inSeconds}秒)';
}

class GitService {
  final LoggerService _logger = LoggerService();
  
  /// 默认超时时间
  static const Duration defaultTimeout = Duration(seconds: 60);
  
  /// 克隆超时时间（克隆可能较慢）
  static const Duration cloneTimeout = Duration(seconds: 180);
  
  /// 推送超时时间
  static const Duration pushTimeout = Duration(seconds: 120);

  /// 获取固定的签名（openHexo）
  Signature _getSignature() {
    return Signature.create(
      name: 'openHexo',
      email: 'openhexo@app.local',
    );
  }

  /// 创建认证凭据
  Credentials? _createCredentials(RepoConfig config) {
    if (config.authToken == null || config.authToken!.isEmpty) {
      return null;
    }
    // 使用用户名和 Token（GitHub Personal Access Token）
    return UserPass(
      username: config.authUsername,
      password: config.authToken!,
    );
  }

  /// 创建回调配置
  Callbacks _createCallbacks(RepoConfig config) {
    return Callbacks(credentials: _createCredentials(config));
  }

  /// 克隆仓库
  Future<String?> cloneRepo(RepoConfig config, {void Function(String)? onProgress}) async {
    try {
      _logger.info('GitService', '开始克隆仓库: ${config.repoUrl}');
      
      final repoDir = Directory(config.localPath);
      
      // 如果目录已存在，删除它
      if (await repoDir.exists()) {
        onProgress?.call('删除旧目录...');
        _logger.debug('GitService', '删除已存在的目录');
        await repoDir.delete(recursive: true);
      }
      
      await repoDir.create(recursive: true);

      onProgress?.call('正在克隆仓库...');

      // 使用 compute 在后台线程执行克隆（避免阻塞 UI）
      // git2dart 的克隆是同步操作，必须在后台执行
      final cloneParams = _CloneParams(
        repoUrl: config.repoUrl,
        localPath: config.localPath,
        authUsername: config.authUsername,
        authToken: config.authToken,
      );
      
      _logger.debug('GitService', '开始后台克隆任务');
      
      final result = await compute(_cloneInIsolate, cloneParams)
          .timeout(
            cloneTimeout,
            onTimeout: () {
              _logger.warning('GitService', '克隆超时');
              return _CloneResult(error: '克隆超时: 网络连接可能不稳定，请检查网络后重试');
            },
          );

      _logger.debug('GitService', '后台克隆任务返回: ${result.error ?? "成功"}');

      if (result.error != null) {
        _logger.error('GitService', '克隆失败: ${result.error}');
        return result.error;
      }

      // 检查并切换到指定分支
      if (config.branch.isNotEmpty) {
        onProgress?.call('检查分支 ${config.branch}...');
        _logger.debug('GitService', '检查分支: ${config.branch}');
        
        final repo = Repository.open(config.localPath);
        try {
          // 获取当前分支名
          String? currentBranch;
          try {
            currentBranch = repo.head.shorthand;
          } catch (_) {
            // HEAD 可能未指向任何分支
          }
          
          _logger.debug('GitService', '当前分支: $currentBranch, 目标分支: ${config.branch}');
          
          // 如果当前分支就是目标分支，无需切换
          if (currentBranch == config.branch) {
            _logger.debug('GitService', '已在目标分支，无需切换');
          } else {
            // 需要切换分支
            onProgress?.call('切换到分支 ${config.branch}...');
            
            // 检查本地分支是否已存在
            bool branchExists = false;
            try {
              Branch.lookup(repo: repo, name: config.branch);
              branchExists = true;
            } catch (_) {
              // 分支不存在
            }
            
            // 如果分支不存在，从远程分支创建
            if (!branchExists) {
              final remoteBranchRef = 'refs/remotes/origin/${config.branch}';
              final remoteBranch = Reference.lookup(repo: repo, name: remoteBranchRef);
              final commit = Commit.lookup(repo: repo, oid: remoteBranch.target);
              Branch.create(repo: repo, name: config.branch, target: commit);
            }
            
            // 切换到该分支
            repo.setHead('refs/heads/${config.branch}');
            Checkout.head(repo: repo);
          }
        } finally {
          repo.free();
        }
      }

      onProgress?.call('克隆完成');
      _logger.info('GitService', '克隆仓库完成: ${config.localPath}');
      
      return null;
    } on TimeoutException {
      _logger.error('GitService', '克隆超时');
      return '克隆超时: 网络连接可能不稳定，请检查网络后重试';
    } catch (e, stackTrace) {
      _logger.error('GitService', '克隆失败', e, stackTrace);
      return '克隆失败: ${_formatError(e)}';
    }
  }

  /// 带超时的执行器
  Future<T?> _runWithTimeout<T>(
    T Function() operation,
    String operationName,
    Duration timeout, {
    void Function(String)? onProgress,
  }) async {
    final completer = Completer<T?>();
    
    // 在新线程中执行同步操作
    Future(() {
      try {
        final result = operation();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    // 添加超时
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _logger.warning('GitService', '$operationName 超时');
        throw GitTimeoutException(operationName, timeout);
      },
    );
  }

  /// 拉取仓库更新
  Future<String?> pullRepo(RepoConfig config, {void Function(String)? onProgress}) async {
    try {
      _logger.info('GitService', '开始拉取更新');
      onProgress?.call('打开本地仓库...');
      
      final repo = Repository.open(config.localPath);
      
      onProgress?.call('获取远程更新...');
      
      // 获取远程仓库
      final remote = Remote.lookup(repo: repo, name: 'origin');
      
      // 执行 fetch
      await _runWithTimeout(
        () => remote.fetch(callbacks: _createCallbacks(config)),
        '获取远程更新',
        defaultTimeout,
        onProgress: onProgress,
      );
      
      onProgress?.call('合并更新...');
      
      // 使用配置的分支名
      final branchName = config.branch;
      
      // 获取远程分支的目标
      final remoteHead = Reference.lookup(
        repo: repo,
        name: 'refs/remotes/origin/$branchName',
      );
      
      // 分析合并
      final analysis = Merge.analysis(
        repo: repo,
        theirHead: remoteHead.target,
      );
      
      // 如果需要合并
      if (analysis.result.contains(GitMergeAnalysis.normal)) {
        final commit = AnnotatedCommit.lookup(
          repo: repo,
          oid: remoteHead.target,
        );
        Merge.commit(repo: repo, commit: commit);
        
        // 创建合并提交
        repo.index.write();
        
        final signature = _getSignature();
        Commit.create(
          repo: repo,
          updateRef: 'HEAD',
          author: signature,
          committer: signature,
          message: 'Merge remote changes\n',
          tree: Tree.lookup(repo: repo, oid: repo.index.writeTree()),
          parents: [
            Commit.lookup(repo: repo, oid: repo.head.target),
            Commit.lookup(repo: repo, oid: remoteHead.target),
          ],
        );
        repo.stateCleanup();
      } else if (analysis.result.contains(GitMergeAnalysis.fastForward)) {
        // 快进合并
        final ref = Reference.lookup(repo: repo, name: 'refs/heads/$branchName');
        Reference.setTarget(
          repo: repo,
          name: ref.name,
          target: remoteHead.target,
          logMessage: 'Fast-forward merge',
        );
        Checkout.head(repo: repo);
      } else if (analysis.result.contains(GitMergeAnalysis.upToDate)) {
        onProgress?.call('已是最新');
      }
      
      remote.free();
      repo.free();
      
      onProgress?.call('拉取完成');
      _logger.info('GitService', '拉取更新完成');
      return null;
    } on GitTimeoutException catch (e) {
      _logger.error('GitService', '拉取超时', e);
      return '拉取超时: 网络连接可能不稳定，请检查网络后重试';
    } catch (e, stackTrace) {
      _logger.error('GitService', '拉取失败', e, stackTrace);
      return '拉取失败: ${_formatError(e)}';
    }
  }

  /// 预览提交信息（不执行推送）
  Future<String?> previewCommitMessage(String localPath) async {
    try {
      _logger.debug('GitService', '开始预览提交信息');
      return await compute(_previewCommitMessage, localPath);
    } catch (e, stackTrace) {
      _logger.error('GitService', '预览提交信息失败', e, stackTrace);
      return null;
    }
  }
  
/// 预览提交信息（顶级函数，供 compute 使用）
String? _previewCommitMessage(String localPath) {
  Repository? repo;
  try {
    repo = Repository.open(localPath);

    // 收集变更的文件信息
    final addedFiles = <String>[];
    final modifiedFiles = <String>[];
    final deletedFiles = <String>[];

    // 获取状态
    final status = repo.status;

    // 收集状态信息
    for (final entry in status.entries) {
      final path = entry.key;
      final statusFlags = entry.value;
      final fullPath = p.join(localPath, path);

      if (statusFlags.contains(GitStatus.wtNew)) {
        addedFiles.add(fullPath);
      } else if (statusFlags.contains(GitStatus.wtModified)) {
        modifiedFiles.add(fullPath);
      } else if (statusFlags.contains(GitStatus.wtDeleted)) {
        deletedFiles.add(fullPath);
      } else if (statusFlags.contains(GitStatus.indexNew)) {
        addedFiles.add(fullPath);
      } else if (statusFlags.contains(GitStatus.indexModified)) {
        modifiedFiles.add(fullPath);
      }
    }

    if (addedFiles.isEmpty && modifiedFiles.isEmpty && deletedFiles.isEmpty) {
      repo.free();
      return null;
    }

    repo.free();

    // 生成提交信息
    return _generateCommitMessage(
      addedFiles: addedFiles,
      modifiedFiles: modifiedFiles,
      deletedFiles: deletedFiles,
      localPath: localPath,
    );
  } catch (e) {
    repo?.free();
    return null;
  }
}

  /// 推送仓库
  Future<String?> pushRepo(String localPath, RepoConfig config, {void Function(String)? onProgress}) async {
    try {
      _logger.info('GitService', '开始推送更新');
      _logger.debug('GitService', '仓库路径: $localPath');

      // 在后台执行整个 Git 操作
      final pushParams = _PushParams(
        localPath: localPath,
        branch: config.branch,
        authUsername: config.authUsername,
        authToken: config.authToken,
      );

      _logger.debug('GitService', '调用 compute 执行推送');
      final result = await compute(_doPushRepo, pushParams);
      _logger.debug('GitService', 'compute 返回: ${result ?? "成功"}');

      if (result == null) {
        _logger.info('GitService', '推送完成');
      } else {
        _logger.warning('GitService', '推送结果: $result');
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error('GitService', '推送失败', e, stackTrace);
      return '推送失败: ${_formatError(e)}';
    }
  }

  /// 删除文章（从仓库中删除文件）
  Future<String?> deleteArticle(String localPath, String articlePath, String commitMessage, RepoConfig config, {void Function(String)? onProgress}) async {
    try {
      _logger.info('GitService', '删除文章: $articlePath');
      onProgress?.call('打开本地仓库...');
      
      final repo = Repository.open(localPath);
      
      onProgress?.call('删除文件...');
      
      // 删除文件
      final file = File(articlePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // 获取相对路径
      final relativePath = articlePath
          .replaceAll('\\', '/')
          .replaceAll('${localPath.replaceAll('\\', '/')}/', '');
      
      // 从索引中移除
      repo.index.remove(relativePath);
      repo.index.write();
      
      onProgress?.call('创建提交...');
      
      // 创建提交
      final signature = _getSignature();
      final tree = Tree.lookup(repo: repo, oid: repo.index.writeTree());
      
      Commit.create(
        repo: repo,
        updateRef: 'HEAD',
        author: signature,
        committer: signature,
        message: commitMessage,
        tree: tree,
        parents: [
          Commit.lookup(repo: repo, oid: repo.head.target),
        ],
      );
      
      onProgress?.call('推送到远程...');
      
      // 推送到远程
      final remote = Remote.lookup(repo: repo, name: 'origin');
      final branchName = config.branch;
      
      await _runWithTimeout(
        () => remote.push(
          refspecs: ['refs/heads/$branchName'],
          callbacks: _createCallbacks(config),
        ),
        '推送到远程',
        pushTimeout,
        onProgress: onProgress,
      );
      
      remote.free();
      repo.free();
      
      onProgress?.call('删除完成');
      _logger.info('GitService', '文章删除完成');
      return null;
    } on GitTimeoutException catch (e) {
      _logger.error('GitService', '删除超时', e);
      return '删除超时: 网络连接可能不稳定，请检查网络后重试';
    } catch (e, stackTrace) {
      _logger.error('GitService', '删除失败', e, stackTrace);
      return '删除失败: ${_formatError(e)}';
    }
  }

  /// 检查仓库是否已克隆
  Future<bool> isRepoCloned(String localPath) async {
    try {
      final repoDir = Directory(localPath);
      if (!await repoDir.exists()) return false;
      
      // 检查是否是 Git 仓库
      final gitDir = Directory(p.join(localPath, '.git'));
      return await gitDir.exists();
    } catch (e) {
      return false;
    }
  }

  /// 格式化错误信息
  String _formatError(dynamic e) {
    final errorStr = e.toString();
    
    // 翻译常见错误
    if (errorStr.contains('authentication') || errorStr.contains('401')) {
      return '认证失败：请检查用户名和访问令牌是否正确';
    }
    if (errorStr.contains('403')) {
      return '权限不足：请确保访问令牌有仓库写入权限';
    }
    if (errorStr.contains('404')) {
      return '仓库不存在：请检查仓库地址是否正确';
    }
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return '网络错误：请检查网络连接';
    }
    if (errorStr.contains('timeout')) {
      return '操作超时：网络可能不稳定，请稍后重试';
    }
    
    return errorStr;
  }

  /// 将文件添加到 Git 索引（用于跟踪新文件或修改的文件）
  Future<void> addFileToIndex(String localPath, String filePath) async {
    try {
      _logger.debug('GitService', '添加文件到索引: $filePath');
      final repo = Repository.open(localPath);

      // 计算相对路径
      final relativePath = filePath
          .replaceAll('\\', '/')
          .replaceAll('${localPath.replaceAll('\\', '/')}/', '');

      repo.index.add(relativePath);
      repo.index.write();
      repo.free();

      _logger.debug('GitService', '成功添加到索引: $relativePath');
    } catch (e) {
      _logger.warning('GitService', '添加文件到索引失败: $e');
      // 忽略错误，不影响主流程
    }
  }
}

/// 克隆参数（用于 Isolate 传递，必须是简单数据类型）
class _CloneParams {
  final String repoUrl;
  final String localPath;
  final String authUsername;
  final String? authToken;
  
  _CloneParams({
    required this.repoUrl,
    required this.localPath,
    required this.authUsername,
    this.authToken,
  });
}

/// 克隆结果
class _CloneResult {
  final String? error;
  
  _CloneResult({required this.error});
}

/// 在后台 Isolate 中执行克隆（顶级函数，供 compute 使用）
_CloneResult _cloneInIsolate(_CloneParams params) {
  try {
    // 创建认证凭据
    Credentials? credentials;
    if (params.authToken != null && params.authToken!.isNotEmpty) {
      credentials = UserPass(
        username: params.authUsername,
        password: params.authToken!,
      );
    }

    final repo = Repository.clone(
      url: params.repoUrl,
      localPath: params.localPath,
      callbacks: Callbacks(credentials: credentials),
    );
    repo.free();
    return _CloneResult(error: null);
  } catch (e) {
    return _CloneResult(error: '克隆失败: $e');
  }
}

/// 推送参数
class _PushParams {
  final String localPath;
  final String branch;
  final String authUsername;
  final String? authToken;

  _PushParams({
    required this.localPath,
    required this.branch,
    required this.authUsername,
    this.authToken,
  });
}

/// 在后台执行推送操作（顶级函数，供 compute 使用）
String? _doPushRepo(_PushParams params) {
  Repository? repo;
  try {
    repo = Repository.open(params.localPath);

    // 收集变更的文件信息
    final addedFiles = <String>[];
    final modifiedFiles = <String>[];
    final deletedFiles = <String>[];

    // 获取状态
    final status = repo.status;

    // 添加所有更改到索引
    for (final entry in status.entries) {
      final path = entry.key;
      final statusFlags = entry.value;
      final fullPath = p.join(params.localPath, path);

      if (statusFlags.contains(GitStatus.wtNew)) {
        repo.index.add(path);
        addedFiles.add(fullPath);
      } else if (statusFlags.contains(GitStatus.wtModified)) {
        repo.index.add(path);
        modifiedFiles.add(fullPath);
      } else if (statusFlags.contains(GitStatus.wtDeleted)) {
        repo.index.remove(path);
        deletedFiles.add(fullPath);
      } else if (statusFlags.contains(GitStatus.indexNew)) {
        addedFiles.add(fullPath);
      } else if (statusFlags.contains(GitStatus.indexModified)) {
        modifiedFiles.add(fullPath);
      }
    }

    if (addedFiles.isEmpty && modifiedFiles.isEmpty && deletedFiles.isEmpty) {
      repo.free();
      return '没有需要推送的更改';
    }

    repo.index.write();

    // 生成提交信息
    final commitMessage = _generateCommitMessage(
      addedFiles: addedFiles,
      modifiedFiles: modifiedFiles,
      deletedFiles: deletedFiles,
      localPath: params.localPath,
    );

    // 创建提交
    final signature = Signature.create(
      name: 'openHexo',
      email: 'openhexo@app.local',
    );
    final tree = Tree.lookup(repo: repo, oid: repo.index.writeTree());

    Commit.create(
      repo: repo,
      updateRef: 'HEAD',
      author: signature,
      committer: signature,
      message: commitMessage,
      tree: tree,
      parents: [
        Commit.lookup(repo: repo, oid: repo.head.target),
      ],
    );

    // 推送到远程
    final remote = Remote.lookup(repo: repo, name: 'origin');
    final branchName = params.branch;

    // 创建凭据
    Credentials? credentials;
    if (params.authToken != null && params.authToken!.isNotEmpty) {
      credentials = UserPass(
        username: params.authUsername,
        password: params.authToken!,
      );
    }

    remote.push(
      refspecs: ['refs/heads/$branchName'],
      callbacks: Callbacks(credentials: credentials),
    );

    remote.free();
    repo.free();

    return null;
  } catch (e) {
    repo?.free();
    return '推送失败: $e';
  }
}

/// 生成符合 Git 社区规范的提交信息
String _generateCommitMessage({
  required List<String> addedFiles,
  required List<String> modifiedFiles,
  required List<String> deletedFiles,
  required String localPath,
}) {
  final buffer = StringBuffer();

  // 提取文章标题
  final addedTitles = _extractArticleTitles(addedFiles, localPath);
  final modifiedTitles = _extractArticleTitles(modifiedFiles, localPath);
  final deletedTitles = _extractArticleTitles(deletedFiles, localPath);

  // 确定提交类型和标题
  String type;
  String subject;

  if (addedTitles.isNotEmpty && modifiedTitles.isEmpty && deletedTitles.isEmpty) {
    type = 'feat';
    subject = '新增 ${addedTitles.length} 篇文章';
  } else if (deletedTitles.isNotEmpty && addedTitles.isEmpty && modifiedTitles.isEmpty) {
    type = 'refactor';
    subject = '删除 ${deletedTitles.length} 篇文章';
  } else {
    type = 'docs';
    final totalChanges = addedTitles.length + modifiedTitles.length + deletedTitles.length;
    subject = '更新 $totalChanges 篇文章';
  }

  // 写入标题行
  buffer.writeln('$type: $subject');
  buffer.writeln();

  // 写入正文
  if (addedTitles.isNotEmpty) {
    buffer.writeln('新增文章:');
    for (final title in addedTitles) {
      buffer.writeln('- $title');
    }
    buffer.writeln();
  }

  if (modifiedTitles.isNotEmpty) {
    buffer.writeln('修改文章:');
    for (final title in modifiedTitles) {
      buffer.writeln('- $title');
    }
    buffer.writeln();
  }

  if (deletedTitles.isNotEmpty) {
    buffer.writeln('删除文章:');
    for (final title in deletedTitles) {
      buffer.writeln('- $title');
    }
  }

  return buffer.toString().trimRight();
}

/// 从 Markdown 文件中提取文章标题
List<String> _extractArticleTitles(List<String> filePaths, String localPath) {
  final titles = <String>[];

  for (final filePath in filePaths) {
    if (!filePath.endsWith('.md')) continue;

    try {
      final file = File(filePath);
      if (!file.existsSync()) continue;

      final content = file.readAsStringSync();
      final title = _parseFrontMatterTitle(content);

      if (title != null && title.isNotEmpty) {
        titles.add(title);
      } else {
        // 如果没有找到标题，使用文件名
        final fileName = p.basenameWithoutExtension(filePath);
        titles.add(fileName);
      }
    } catch (e) {
      // 如果读取失败，使用文件名
      final fileName = p.basenameWithoutExtension(filePath);
      titles.add(fileName);
    }
  }

  return titles;
}

/// 解析 Markdown 文件的 front matter 获取标题
String? _parseFrontMatterTitle(String content) {
  // 检查是否以 --- 开头
  if (!content.startsWith('---')) return null;

  // 找到第二个 ---
  final endIndex = content.indexOf('---', 3);
  if (endIndex == -1) return null;

  // 提取 front matter
  final frontMatter = content.substring(3, endIndex).trim();

  // 查找 title 字段
  final lines = frontMatter.split('\n');
  for (final line in lines) {
    final trimmedLine = line.trim();
    if (trimmedLine.startsWith('title:')) {
      // 提取标题值
      var title = trimmedLine.substring(6).trim();

      // 去除引号
      if ((title.startsWith('"') && title.endsWith('"')) ||
          (title.startsWith("'") && title.endsWith("'"))) {
        title = title.substring(1, title.length - 1);
      }

      return title.isNotEmpty ? title : null;
    }
  }

  return null;
}
