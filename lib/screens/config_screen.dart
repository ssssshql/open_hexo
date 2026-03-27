import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../models/repo_config.dart';
import '../utils/app_info.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _repoUrlController;
  late TextEditingController _authUsernameController;
  late TextEditingController _authTokenController;
  late TextEditingController _branchController;
  String _defaultLocalPath = '';
  bool _pathLoaded = false;

  @override
  void initState() {
    super.initState();
    _repoUrlController = TextEditingController();
    _authUsernameController = TextEditingController();
    _authTokenController = TextEditingController();
    _branchController = TextEditingController(text: 'main');

    _loadDefaultPath();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateControllers();
    });
  }

  Future<void> _loadDefaultPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final localPath = p.join(appDir.path, 'hexo_blog');
    if (mounted) {
      setState(() {
        _defaultLocalPath = localPath;
        _pathLoaded = true;
      });
    }
  }

  void _updateControllers() {
    final config = context.read<AppState>().config;
    if (config != null && mounted) {
      setState(() {
        _repoUrlController.text = config.repoUrl;
        _authUsernameController.text = config.authUsername;
        _authTokenController.text = config.authToken ?? '';
        _branchController.text = config.branch.isNotEmpty ? config.branch : 'main';
      });
    }
  }

  @override
  void dispose() {
    _repoUrlController.dispose();
    _authUsernameController.dispose();
    _authTokenController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final appState = context.read<AppState>();

    final branchText = _branchController.text.trim();
    final config = RepoConfig(
      repoUrl: _repoUrlController.text.trim(),
      localPath: '',
      authUsername: _authUsernameController.text.trim(),
      authToken: _authTokenController.text.trim().isEmpty
          ? null
          : _authTokenController.text.trim(),
      branch: branchText.isEmpty ? 'main' : branchText,
    );

    await appState.saveConfig(config);

    final success = await appState.cloneRepo();
    if (success && mounted) {
      await appState.loadArticles();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '配置已保存，仓库克隆成功' : '配置已保存')),
      );
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature功能正在开发中，敬请期待'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              // 外观设置
              _buildSectionHeader('外观'),
              _buildCard([
                _buildTile(
                  icon: Icons.palette_outlined,
                  iconColor: Colors.deepPurple,
                  title: '主题',
                  subtitle: '跟随系统',
                  onTap: () => _showComingSoon('主题切换'),
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.language,
                  iconColor: Colors.blue,
                  title: '界面语言',
                  subtitle: '简体中文',
                  onTap: () => _showComingSoon('语言切换'),
                ),
              ]),

              const SizedBox(height: 24),

              // GitHub 仓库配置
              _buildSectionHeaderWithAction('GitHub 仓库', () => _saveConfig()),
              _buildCard([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextFormField(
                    controller: _repoUrlController,
                    decoration: InputDecoration(
                      label: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '仓库地址 ', style: TextStyle(color: colorScheme.onSurface)),
                            const TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      hintText: 'https://github.com/username/repo.git',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入仓库地址';
                      }
                      final url = value.trim();
                      final uri = Uri.tryParse(url);
                      if (uri == null || !uri.hasScheme) {
                        return '请输入有效的仓库地址';
                      }
                      if (!url.startsWith('http://') &&
                          !url.startsWith('https://') &&
                          !url.startsWith('git@')) {
                        return '支持 https:// 或 git@ 格式';
                      }
                      return null;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextFormField(
                    controller: _authUsernameController,
                    decoration: InputDecoration(
                      label: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '认证用户名 ', style: TextStyle(color: colorScheme.onSurface)),
                            const TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      hintText: 'Git 服务账号用户名',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入认证用户名';
                      }
                      return null;
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextFormField(
                  controller: _authTokenController,
                  decoration: const InputDecoration(
                    labelText: '访问令牌',
                    hintText: '推送时需要（可选）',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: () async {
                    final uri = Uri.parse('https://docs.github.com/zh/rest/authentication/authenticating-to-the-rest-api');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'GitHub 访问令牌官方说明',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: TextFormField(
                  controller: _branchController,
                  decoration: const InputDecoration(
                    labelText: '分支',
                    hintText: '默认为 main',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (_pathLoaded && _defaultLocalPath.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.folder_outlined, color: Colors.grey.shade600),
                  title: const Text('本地路径', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    _defaultLocalPath,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ]),

            // 错误提示
            Consumer<AppState>(
              builder: (context, appState, child) {
                if (appState.errorMessage == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            appState.errorMessage!,
                            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: appState.clearError,
                          color: Colors.red.shade700,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // 版本信息
            Center(
              child: Text(
                AppInfo.fullVersion,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildSectionHeaderWithAction(String title, VoidCallback onConnect) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          Consumer<AppState>(
            builder: (context, appState, child) {
              final isConnected = appState.isConfigured;
              final isLoading = appState.isLoading;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 清除配置按钮
                  if (isConnected && !isLoading)
                    InkWell(
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('清除配置'),
                            content: const Text('确定要清除所有配置吗？本地仓库不会被删除。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('清除'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && mounted) {
                          await appState.clearConfig();
                          _repoUrlController.clear();
                          _authUsernameController.clear();
                          _authTokenController.clear();
                          _branchController.text = 'main';
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline, size: 14, color: Colors.red.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '清除',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),
                  if (isConnected && !isLoading)
                    const SizedBox(width: 8),
                  // Connect 按钮
                  InkWell(
                    onTap: isLoading ? null : onConnect,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? Colors.green.shade50
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            )
                          else
                            Icon(
                              isConnected ? Icons.check : Icons.link,
                              size: 14,
                              color: isConnected
                                  ? Colors.green.shade600
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            isLoading
                                ? '连接中'
                                : isConnected
                                    ? '已连接'
                                    : '连接',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isConnected
                                  ? Colors.green.shade600
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56);
  }
}
