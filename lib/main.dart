import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:git2dart/git2dart.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'services/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化日志服务
  final logger = LoggerService();
  await logger.init();
  logger.info('Main', '应用启动');
  
  // Android 平台初始化 git2dart
  if (Platform.isAndroid) {
    await PlatformSpecific.androidInitialize();
    logger.debug('Main', 'git2dart 初始化完成 (Android)');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppState _appState;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _appState.loadConfig();
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    return ChangeNotifierProvider.value(
      value: _appState,
      child: MaterialApp(
        title: 'Open Hexo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
