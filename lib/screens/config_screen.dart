import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/repo_config.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGitConfigSection(),
            const SizedBox(height: 24),
            // 预留其他设置分组
            // _buildThemeConfigSection(),
            // _buildModelConfigSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildGitConfigSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Row(
          children: [
            Icon(Icons.source_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Git 仓库',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 表单字段
        TextFormField(
          controller: _repoUrlController,
          decoration: InputDecoration(
            label: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: '仓库地址 ', style: TextStyle(color: Colors.grey.shade700)),
                  const TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            hintText: 'https://github.com/username/repo.git',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        const SizedBox(height: 12),
        TextFormField(
          controller: _authUsernameController,
          decoration: InputDecoration(
            label: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: '认证用户名 ', style: TextStyle(color: Colors.grey.shade700)),
                  const TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            hintText: 'Git 服务账号用户名',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入认证用户名';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _authTokenController,
          decoration: const InputDecoration(
            labelText: '访问令牌（推送时需要）',
            hintText: 'GitHub Personal Access Token',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _branchController,
          decoration: const InputDecoration(
            labelText: '分支',
            hintText: '默认为 main',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // 本地路径显示
        if (_pathLoaded && _defaultLocalPath.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '本地路径: $_defaultLocalPath',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // 操作按钮
        Consumer<AppState>(
          builder: (context, appState, child) {
            return Column(
              children: [
                // 错误提示
                if (appState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(height: 12),
                ],

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: appState.isLoading ? null : _saveConfig,
                    icon: appState.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(appState.isLoading ? '处理中...' : '保存'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // 清除按钮
                if (appState.isConfigured) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: appState.isLoading
                        ? null
                        : () async {
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
                    child: const Text('清除配置', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
