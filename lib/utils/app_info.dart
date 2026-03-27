import 'package:package_info_plus/package_info_plus.dart';

/// 应用信息工具类
class AppInfo {
  static String _version = '1.0.0';
  static String _appName = 'Open Hexo';
  static bool _initialized = false;

  /// 获取版本号
  static String get version => _version;

  /// 获取应用名称
  static String get appName => _appName;

  /// 获取完整版本字符串
  static String get fullVersion => '$_appName v$_version';

  /// 初始化应用信息（应用启动时调用）
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _version = packageInfo.version;
      _appName = packageInfo.appName;
      _initialized = true;
    } catch (e) {
      // 使用默认值
      _initialized = true;
    }
  }
}
