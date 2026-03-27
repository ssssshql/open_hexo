import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_info.dart';
import 'logger_service.dart';

/// 版本信息模型
class VersionInfo {
  final String version;
  final String buildTime;
  final String? arm64V8a;
  final String? armeabiV7a;

  VersionInfo({
    required this.version,
    required this.buildTime,
    this.arm64V8a,
    this.armeabiV7a,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'] as String? ?? '0.0.0',
      buildTime: json['build_time'] as String? ?? '',
      arm64V8a: json['arm64-v8a'] as String?,
      armeabiV7a: json['armeabi-v7a'] as String?,
    );
  }
}

/// 更新检查结果
enum UpdateStatus {
  hasUpdate, // 有新版本
  noUpdate, // 已是最新版本
  networkError, // 网络错误
}

class UpdateResult {
  final UpdateStatus status;
  final VersionInfo? versionInfo;

  UpdateResult({
    required this.status,
    this.versionInfo,
  });
}

/// 更新服务
class UpdateService {
  static const String _versionUrl =
      'https://blog.19991029.xyz/open_hexo/version.json';

  static final Dio _dio = Dio();

  /// 检查更新
  static Future<UpdateResult> checkUpdate() async {
    try {
      final response = await _dio.get(
        _versionUrl,
        options: Options(
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data;
        if (response.data is String) {
          data = json.decode(response.data);
        } else {
          data = response.data;
        }

        final versionInfo = VersionInfo.fromJson(data);
        final currentVersion = AppInfo.version;

        // 比较版本号
        if (_compareVersions(versionInfo.version, currentVersion) > 0) {
          return UpdateResult(status: UpdateStatus.hasUpdate, versionInfo: versionInfo);
        }
      }
      return UpdateResult(status: UpdateStatus.noUpdate);
    } catch (e) {
      LoggerService().error('UpdateService', '检查更新失败: $e');
      return UpdateResult(status: UpdateStatus.networkError);
    }
  }

  /// 获取设备架构对应的下载链接
  static String? getDownloadUrl(VersionInfo versionInfo) {
    if (!Platform.isAndroid) return null;

    // 获取设备支持的 ABI
    final abi = defaultTargetPlatform == TargetPlatform.android
        ? Platform.version.contains('arm64')
            ? 'arm64-v8a'
            : 'armeabi-v7a'
        : 'arm64-v8a';

    if (abi == 'arm64-v8a' && versionInfo.arm64V8a != null) {
      return versionInfo.arm64V8a;
    } else if (versionInfo.armeabiV7a != null) {
      return versionInfo.armeabiV7a;
    }

    // 默认返回 arm64-v8a
    return versionInfo.arm64V8a ?? versionInfo.armeabiV7a;
  }

  /// 下载并安装 APK
  /// [progress] 下载进度回调 (0-100)
  static Future<bool> downloadAndInstall(
    String url, {
    void Function(int)? onProgress,
  }) async {
    try {
      // 获取下载目录
      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last;
      final filePath = '${tempDir.path}/$fileName';

      LoggerService().info('UpdateService', '开始下载: $url');

      // 下载文件
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            final progress = ((received / total) * 100).round();
            onProgress(progress);
          }
        },
      );

      LoggerService().info('UpdateService', '下载完成: $filePath');

      // 安装 APK
      final result = await OpenFile.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        LoggerService().error('UpdateService', '打开 APK 失败: ${result.message}');
        return false;
      }

      return true;
    } catch (e) {
      LoggerService().error('UpdateService', '下载安装失败: $e');
      return false;
    }
  }

  /// 比较版本号
  /// 返回 >0 表示 v1 > v2, <0 表示 v1 < v2, =0 表示相等
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }
}
