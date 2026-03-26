import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/custom_toast.dart';
import 'config_screen.dart';
import 'article_list_screen.dart';
import 'article_edit_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isFABExpanded = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final appState = context.read<AppState>();
    await appState.loadConfig();
    
    if (appState.isConfigured && mounted) {
      // 确保仓库已准备好（已克隆或执行克隆）
      final ready = await appState.ensureRepoReady();
      if (ready && mounted) {
        await appState.loadArticles();
      }
    }
  }

  Future<void> _pullRepo() async {
    final success = await context.read<AppState>().pullRepo();
    if (success && mounted) {
      CustomToast.show(
        context,
        message: '拉取成功',
        type: ToastType.success,
      );
    }
  }

  Future<void> _pushRepo() async {
    // 先预览提交信息
    final commitMessage = await context.read<AppState>().previewCommitMessage();
    
    if (!mounted) return;
    
    if (commitMessage == null) {
      CustomToast.show(
        context,
        message: '没有需要推送的更改',
        type: ToastType.warning,
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认推送'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('提交信息:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  commitMessage,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<AppState>().pushRepo();
      
      if (success && mounted) {
        CustomToast.show(
          context,
          message: '推送成功',
          type: ToastType.success,
        );
      }
    }
  }

  Widget _buildMiniFAB({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: label,
          mini: true,
          shape: const CircleBorder(),
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Consumer<AppState>(
            builder: (context, appState, child) {
              return IndexedStack(
                index: _currentIndex,
                children: [
                  const ArticleListScreen(),
                  const ConfigScreen(),
                  const AboutScreen(),
                ],
              );
            },
          ),
          bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '文章',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '配置',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: '关于',
          ),
        ],
      ),
        floatingActionButton: _currentIndex == 0
          ? Consumer<AppState>(
              builder: (context, appState, child) {
                if (!appState.isConfigured) {
                  return const SizedBox.shrink();
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_isFABExpanded) ...[
                      _buildMiniFAB(
                        icon: Icons.add,
                        label: '新建',
                        onPressed: () {
                          setState(() => _isFABExpanded = false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ArticleEditScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMiniFAB(
                        icon: Icons.cloud_download,
                        label: '拉取',
                        onPressed: () {
                          setState(() => _isFABExpanded = false);
                          _pullRepo();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMiniFAB(
                        icon: Icons.cloud_upload,
                        label: '推送',
                        onPressed: () {
                          setState(() => _isFABExpanded = false);
                          _pushRepo();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    FloatingActionButton(
                      heroTag: 'main',
                      shape: const CircleBorder(),
                      onPressed: () {
                        setState(() => _isFABExpanded = !_isFABExpanded);
                      },
                      child: AnimatedRotation(
                        turns: _isFABExpanded ? 0.125 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(_isFABExpanded ? Icons.close : Icons.menu),
                      ),
                    ),
                  ],
                );
              },
            )
          : null,
        ),
        // 全局加载遮罩层
        Consumer<AppState>(
          builder: (context, appState, child) {
            if (!appState.isLoading) return const SizedBox.shrink();
            
            return Positioned.fill(
              child: Container(
                color: Colors.black38,
                child: Center(
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            appState.statusMessage,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
