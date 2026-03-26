class RepoConfig {
  final String repoUrl;
  final String localPath;
  final String authUsername; // 认证用户名（用于 git 认证）
  final String? authToken;   // 访问令牌（密码/Token）
  final String branch;       // 分支名，默认 main

  RepoConfig({
    required this.repoUrl,
    required this.localPath,
    required this.authUsername,
    this.authToken,
    this.branch = 'main',
  });

  Map<String, dynamic> toJson() => {
        'repoUrl': repoUrl,
        'localPath': localPath,
        'authUsername': authUsername,
        'authToken': authToken,
        'branch': branch,
      };

  factory RepoConfig.fromJson(Map<String, dynamic> json) => RepoConfig(
        repoUrl: json['repoUrl'] ?? '',
        localPath: json['localPath'] ?? '',
        authUsername: json['authUsername'] ?? json['username'] ?? '', // 兼容旧配置
        authToken: json['authToken'] ?? json['password'],
        branch: json['branch'] ?? 'main',
      );

  RepoConfig copyWith({
    String? repoUrl,
    String? localPath,
    String? authUsername,
    String? authToken,
    String? branch,
  }) {
    return RepoConfig(
      repoUrl: repoUrl ?? this.repoUrl,
      localPath: localPath ?? this.localPath,
      authUsername: authUsername ?? this.authUsername,
      authToken: authToken ?? this.authToken,
      branch: branch ?? this.branch,
    );
  }
}
