import 'dart:io';
import 'package:git2dart/git2dart.dart';
import 'package:path/path.dart' as p;
import '../models/repo_config.dart';

class GitService {
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
    // 使用用户名和 Token
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
      final repoDir = Directory(config.localPath);
      
      // 如果目录已存在，删除它
      if (await repoDir.exists()) {
        onProgress?.call('删除旧目录...');
        await repoDir.delete(recursive: true);
      }
      
      await repoDir.create(recursive: true);

      onProgress?.call('正在克隆仓库...');

      // 使用 git2dart 克隆
      final repo = Repository.clone(
        url: config.repoUrl,
        localPath: config.localPath,
        callbacks: _createCallbacks(config),
      );

      // 如果分支不是默认分支，需要切换
      final defaultBranch = repo.head.shorthand;
      if (config.branch.isNotEmpty && config.branch != defaultBranch) {
        onProgress?.call('切换到分支 ${config.branch}...');
        
        // 获取远程分支
        final remoteBranchRef = 'refs/remotes/origin/${config.branch}';
        final remoteBranch = Reference.lookup(repo: repo, name: remoteBranchRef);
        
        // 创建本地分支
        final commit = Commit.lookup(repo: repo, oid: remoteBranch.target);
        Branch.create(repo: repo, name: config.branch, target: commit);
        
        // 切换到该分支
        Reference.setTarget(
          repo: repo,
          name: 'refs/HEAD',
          target: 'refs/heads/${config.branch}',
          logMessage: 'checkout: moving to ${config.branch}',
        );
        Checkout.head(repo: repo);
      }

      onProgress?.call('克隆完成');
      
      // 释放资源
      repo.free();
      return null;
    } catch (e) {
      return '克隆失败: $e';
    }
  }

  /// 拉取仓库更新
  Future<String?> pullRepo(RepoConfig config, {void Function(String)? onProgress}) async {
    try {
      onProgress?.call('打开本地仓库...');
      
      final repo = Repository.open(config.localPath);
      
      onProgress?.call('获取远程更新...');
      
      // 获取远程仓库
      final remote = Remote.lookup(repo: repo, name: 'origin');
      
      // 执行 fetch
      remote.fetch(callbacks: _createCallbacks(config));
      
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
      return null;
    } catch (e) {
      return '拉取失败: $e';
    }
  }

  /// 推送仓库
  Future<String?> pushRepo(String localPath, String commitMessage, RepoConfig config, {void Function(String)? onProgress}) async {
    try {
      onProgress?.call('打开本地仓库...');
      
      final repo = Repository.open(localPath);
      
      onProgress?.call('扫描更改...');
      
      // 获取状态
      final status = repo.status;
      
      if (status.isEmpty) {
        repo.free();
        return '没有需要推送的更改';
      }
      
      onProgress?.call('添加更改到暂存区...');
      
      // 添加所有更改到索引
      for (final entry in status.entries) {
        final path = entry.key;
        final statusFlags = entry.value;
        
        if (statusFlags.contains(GitStatus.wtNew) ||
            statusFlags.contains(GitStatus.wtModified)) {
          repo.index.add(path);
        }
      }
      
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
      
      // 使用配置的分支名
      final branchName = config.branch;
      
      remote.push(
        refspecs: ['refs/heads/$branchName'],
        callbacks: _createCallbacks(config),
      );
      
      remote.free();
      repo.free();
      
      onProgress?.call('推送完成');
      return null;
    } catch (e) {
      return '推送失败: $e';
    }
  }

  /// 删除文章（从仓库中删除文件）
  Future<String?> deleteArticle(String localPath, String articlePath, String commitMessage, RepoConfig config, {void Function(String)? onProgress}) async {
    try {
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
      
      remote.push(
        refspecs: ['refs/heads/$branchName'],
        callbacks: _createCallbacks(config),
      );
      
      remote.free();
      repo.free();
      
      onProgress?.call('删除完成');
      return null;
    } catch (e) {
      return '删除失败: $e';
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
}
