import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/image_viewer.dart';
import '../utils/app_info.dart';
import '../services/update_service.dart';
import 'log_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    // 进入页面时自动检查更新（仅 Android）
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdate(autoCheck: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, weight: 600),
            tooltip: '运行日志',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 应用信息卡片
          _buildAppInfoCard(context),
          const SizedBox(height: 16),

          // 开源地址卡片
          _buildOpenSourceCard(context),
          const SizedBox(height: 16),

          // 未来功能卡片
          _buildRoadmapCard(context),
          const SizedBox(height: 16),

          // 开源致谢卡片
          _buildThanksCard(context),
          const SizedBox(height: 16),

          // 开发信息卡片
          _buildDevInfoCard(context),
          const SizedBox(height: 16),

          // 捐赠卡片
          _buildDonationCard(context),

          // 捐赠名单卡片（仅在有捐赠者时显示）
          _buildDonorListCard(context),
        ],
      ),
    );
  }

  /// 检查更新
  /// [autoCheck] 是否为自动检查（进入页面时），自动检查不显示"已是最新版本"提示
  Future<void> _checkForUpdate({bool autoCheck = false}) async {
    if (_checkingUpdate) return;

    setState(() => _checkingUpdate = true);

    try {
      final result = await UpdateService.checkUpdate();

      if (!mounted) return;

      switch (result.status) {
        case UpdateStatus.hasUpdate:
          // 有新版本，显示更新对话框
          _showUpdateDialog(result.versionInfo!);
        case UpdateStatus.noUpdate:
          // 已是最新版本，仅手动检查时提示
          if (!autoCheck) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('当前已是最新版本')),
            );
          }
        case UpdateStatus.networkError:
          // 网络错误
          if (!autoCheck) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('暂时无法访问服务器')),
            );
          }
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(VersionInfo versionInfo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新版本：${versionInfo.version}'),
            const SizedBox(height: 8),
            Text('当前版本：${AppInfo.version}'),
            if (versionInfo.buildTime.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('发布时间：${versionInfo.buildTime}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startUpdate(versionInfo);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  /// 开始更新
  void _startUpdate(VersionInfo versionInfo) {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂只支持 Android 平台自动更新')),
      );
      return;
    }

    final downloadUrl = UpdateService.getDownloadUrl(versionInfo);
    if (downloadUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到适配的安装包')),
      );
      return;
    }

    final progressNotifier = ValueNotifier<int>(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: progressNotifier,
        builder: (ctx, progress, _) => AlertDialog(
          title: const Text('正在下载'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress / 100),
              const SizedBox(height: 16),
              Text('$progress%'),
            ],
          ),
        ),
      ),
    );

    UpdateService.downloadAndInstall(
      downloadUrl,
      onProgress: (p) {
        progressNotifier.value = p;
      },
    ).then((success) {
      progressNotifier.dispose();
      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新失败，请稍后重试')),
          );
        }
      }
    });
  }

  Widget _buildAppInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_note,
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Hexo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '版本 ${AppInfo.version}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // 检查更新按钮
              if (Platform.isAndroid)
                TextButton.icon(
                  onPressed: _checkingUpdate ? null : _checkForUpdate,
                  icon: _checkingUpdate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update, size: 18),
                  label: Text(_checkingUpdate ? '检查中' : '检查更新'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            '一个简洁的 Hexo 博客管理应用，支持文章编辑、Git 推送等功能。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildOpenSourceCard(BuildContext context) {
    const githubUrl = 'https://github.com/ssssshql/open_hexo';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  '开源地址',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '本项目基于 MIT 协议开源，欢迎 Star、Fork 和提交 PR。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final uri = Uri.parse(githubUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              onLongPress: () {
                Clipboard.setData(const ClipboardData(text: githubUrl));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('链接已复制到剪贴板')));
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        githubUrl,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapCard(BuildContext context) {
    final features = [
      {'icon': Icons.translate, 'title': '国际化 (i18n)', 'desc': '支持多语言切换'},
      {'icon': Icons.auto_awesome, 'title': 'AI 润色', 'desc': '智能优化文章表达'},
      {'icon': Icons.system_update, 'title': '在线更新', 'desc': '自动检测并更新版本'},
      {'icon': Icons.image, 'title': '图片上传', 'desc': '支持 PicGo 等图床'},
      {'icon': Icons.edit_note, 'title': '编辑器增强', 'desc': '工具栏、实时预览'},
      {'icon': Icons.download, 'title': '数据导出', 'desc': '导出文章备份'},
      {'icon': Icons.bar_chart, 'title': '文章统计', 'desc': '字数、阅读时间统计'},
      {'icon': Icons.cloud_sync, 'title': 'WebDAV 同步', 'desc': '跨设备数据同步'},
      {'icon': Icons.palette, 'title': '主题定制', 'desc': '深色/浅色主题切换'},
      {'icon': Icons.delete_outline, 'title': '回收站', 'desc': '误删文章可恢复'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.upcoming,
                  color: Color.lerp(Colors.grey, Colors.lightBlue, 0.2),
                ),
                const SizedBox(width: 8),
                Text(
                  '开发路线图',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('未来计划开发的功能：', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      feature['icon'] as IconData,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            feature['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThanksCard(BuildContext context) {
    final projects = [
      {'name': 'Flutter', 'desc': 'UI 框架'},
      {'name': 'git2dart', 'desc': 'Git 操作库'},
      {'name': 'flutter_markdown', 'desc': 'Markdown 渲染'},
      {'name': 'flutter_highlight', 'desc': '代码高亮'},
      {'name': 'Provider', 'desc': '状态管理'},
      {'name': 'gal', 'desc': '图片保存'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.volunteer_activism,
                  color: Color.lerp(Colors.grey, Colors.teal, 0.2),
                ),
                const SizedBox(width: 8),
                Text(
                  '开源致谢',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('感谢以下开源项目：', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: projects
                  .map(
                    (project) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${project['name']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '开发信息',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('框架', 'Flutter'),
            _buildInfoRow('语言', 'Dart'),
            _buildInfoRow('Git 库', 'git2dart'),
            _buildInfoRow('Markdown', 'flutter_markdown + flutter_highlight'),
            _buildInfoRow('状态管理', 'Provider'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildDonationCard(BuildContext context) {
    const donationImageUrl =
        'https://picgo.19991029.xyz/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20260327133527_246_36.png';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Color.lerp(Colors.grey, Colors.red, 0.2),
                ),
                const SizedBox(width: 8),
                Text(
                  '捐赠',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '如果您觉得这个应用对您有帮助，欢迎请作者喝杯咖啡 ☕',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '捐赠时请备注您的名称，将显示在软件的捐赠名单中',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            // 付款码图片 - 居中显示
            Center(
              child: GestureDetector(
                onTap: () => ImageViewer.show(context, donationImageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 240,
                    height: 300,
                    color: Colors.transparent,
                    child: Image.network(
                      donationImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 36,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '图片加载失败',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorListCard(BuildContext context) {
    // TODO: 从接口获取捐赠名单
    // 示例数据结构：
    // final donors = await fetchDonors();
    // 接口返回格式：[{ "name": "张三", "amount": "10", "date": "2024-01-01" }, ...]

    // 暂无捐赠者时，不显示此卡片
    final donors = <dynamic>[]; // 替换为实际接口数据
    if (donors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: Color.lerp(Colors.grey, Colors.orange, 0.35),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '捐赠名单',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '感谢以下捐赠者的支持 ❤️',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                // TODO: 根据 donors 数据渲染捐赠者列表
              ],
            ),
          ),
        ),
      ],
    );
  }
}
