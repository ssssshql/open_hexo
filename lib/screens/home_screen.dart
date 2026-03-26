import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'config_screen.dart';
import 'article_list_screen.dart';
import 'article_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _commitMessageController = TextEditingController();

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('拉取成功')),
      );
    }
  }

  Future<void> _pushRepo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('推送更改'),
        content: TextField(
          controller: _commitMessageController,
          decoration: const InputDecoration(
            labelText: '提交信息',
            hintText: '输入本次更改的描述',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('推送'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final message = _commitMessageController.text.trim().isEmpty
          ? '更新文章 ${DateTime.now().toString().split('.').first}'
          : _commitMessageController.text.trim();
      
      final success = await context.read<AppState>().pushRepo(message);
      _commitMessageController.clear();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('推送成功')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commitMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return IndexedStack(
            index: _currentIndex,
            children: [
              const ArticleListScreen(),
              const ConfigScreen(),
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
                  children: [
                    FloatingActionButton(
                      heroTag: 'add',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ArticleEditScreen(),
                          ),
                        );
                      },
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'pull',
                      onPressed: _pullRepo,
                      child: const Icon(Icons.cloud_download),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'push',
                      onPressed: _pushRepo,
                      child: const Icon(Icons.cloud_upload),
                    ),
                  ],
                );
              },
            )
          : null,
    );
  }
}
