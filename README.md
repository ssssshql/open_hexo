# Open Hexo

<div align="center">

一个跨平台的 Hexo 博客管理客户端。

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-android-green.svg)](https://flutter.dev)

</div>

---

> **当前支持平台**：Android
>
> iOS、Windows、macOS、Linux 平台支持正在规划中。

---

## ✨ 功能特性

### 📝 文章管理
- **文章列表**：支持列表视图和时间线视图切换
- **文章编辑**：Markdown 编辑器，支持实时预览
- **文章预览**：精美的文章详情页面
- **智能图标**：根据文章标签自动匹配图标

### 🔧 Git 集成
- **仓库克隆**：一键克隆 Hexo 博客仓库
- **拉取推送**：快速同步本地和远程仓库
- **自动提交**：保存文章自动添加到 Git 索引

### 🎨 界面设计
- **现代 UI**：Material Design 3 设计风格
- **深色模式**：自动跟随系统主题
- **Hero 动画**：流畅的页面过渡效果
- **响应式布局**：适配各种屏幕尺寸

### 📂 多平台支持

当前支持：
- ✅ Android

计划支持：
- 🔲 iOS
- 🔲 Windows
- 🔲 macOS
- 🔲 Linux

---

## 🚀 快速开始

### 环境要求

- Flutter SDK 3.24 或更高版本
- Dart SDK 3.0 或更高版本
- Git

### 安装步骤

1. **克隆仓库**
```bash
git clone https://github.com/your-username/open_hexo.git
cd open_hexo
```

2. **安装依赖**
```bash
flutter pub get
```

3. **运行应用**
```bash
flutter run
```

### 构建发布版本

#### 本地构建

```bash
# Android APK
flutter build apk --release

# Android App Bundle (用于上架 Google Play)
flutter build appbundle --release
```

#### 自动构建（GitHub Actions）

本项目配置了 GitHub Actions 自动构建签名的 APK。详见 [GitHub Actions 配置指南](docs/GITHUB_ACTIONS.md)。

**快速开始：**

1. 配置 GitHub Secrets（详见配置指南）
2. 创建 tag 触发构建：
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. 在 Releases 页面下载签名的 APK

---

## 📖 使用说明

### 首次配置

1. 打开应用，进入「配置」页面
2. 填写 GitHub 仓库信息：
   - 仓库地址（必填）
   - 认证用户名（必填）
   - 访问令牌（推送时需要）
   - 分支（默认 main）
3. 点击「连接」按钮，自动克隆仓库

### 文章操作

- **新建文章**：点击右下角浮动按钮 → 新建
- **编辑文章**：点击文章卡片的编辑图标
- **预览文章**：点击文章卡片
- **删除文章**：在编辑页面点击删除按钮

### Git 同步

- **拉取更新**：点击浮动按钮 → 拉取
- **推送更改**：点击浮动按钮 → 推送

---

## 🛠️ 技术栈

- **框架**：[Flutter](https://flutter.dev)
- **状态管理**：[Provider](https://pub.dev/packages/provider)
- **Git 操作**：直接调用 Git 命令行工具
- **Markdown 解析**：[flutter_markdown](https://pub.dev/packages/flutter_markdown)
- **YAML 解析**：[yaml](https://pub.dev/packages/yaml)
- **路径处理**：[path](https://pub.dev/packages/path)

---

## 📂 项目结构

```
open_hexo/
├── lib/
│   ├── models/          # 数据模型
│   ├── providers/       # 状态管理
│   ├── screens/         # 页面
│   ├── services/        # 业务逻辑
│   ├── widgets/         # 自定义组件
│   └── main.dart        # 应用入口
├── android/             # Android 平台代码
├── .github/
│   └── workflows/       # GitHub Actions 工作流
├── docs/                # 文档
├── test/                # 测试文件
├── LICENSE              # MIT 许可证
└── README.md            # 项目说明
```

---

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

---

## 📝 开发计划

- [x] GitHub Actions 自动构建签名 APK
- [ ] 主题切换功能
- [ ] 多语言支持
- [ ] 图片上传管理
- [ ] 文章分类管理
- [ ] 草稿箱功能
- [ ] 文章搜索优化
- [ ] 自定义编辑器主题
- [ ] iOS、Windows、macOS、Linux 平台支持

---

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

## 🙏 致谢

感谢以下开源项目：

- [Flutter](https://flutter.dev)
- [Hexo](https://hexo.io)
- 所有依赖包的贡献者

---

<div align="center">

**如果这个项目对你有帮助，请给一个 ⭐️ Star 支持一下！**

</div>
