import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/repo_config.dart';

class ConfigService {
  static const String _configKey = 'hexo_repo_config';

  Future<RepoConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString(_configKey);
    if (configStr == null) return null;
    
    try {
      final json = jsonDecode(configStr) as Map<String, dynamic>;
      return RepoConfig.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveConfig(RepoConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
  }
}
