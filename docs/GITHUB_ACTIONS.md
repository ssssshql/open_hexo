# GitHub Actions 配置指南

本文档说明如何配置 GitHub Actions 自动构建签名的 APK。

## 📋 前置要求

- 已有 Android 签名密钥（keystore 文件）
- 如没有，请先创建签名密钥

## 🔑 创建签名密钥

如果您还没有签名密钥，可以使用以下命令创建：

```bash
keytool -genkey -v -keystore open-hexo.jks -keyalg RSA -keysize 2048 -validity 10000 -alias open-hexo
```

按提示输入以下信息：
- 密钥库口令（storePassword）
- 密钥口令（keyPassword）
- 姓名、组织、城市等信息

## 🔐 配置 GitHub Secrets

在您的 GitHub 仓库中，进入 **Settings → Secrets and variables → Actions**，添加以下 secrets：

### 必需的 Secrets

| Secret 名称 | 说明 | 示例 |
|------------|------|------|
| `ANDROID_KEYSTORE_BASE64` | keystore 文件的 base64 编码 | 见下方说明 |
| `ANDROID_KEY_ALIAS` | 密钥别名 | `open-hexo` |
| `ANDROID_KEY_PASSWORD` | 密钥口令 | 您设置的 keyPassword |
| `ANDROID_STORE_PASSWORD` | 密钥库口令 | 您设置的 storePassword |

### 生成 ANDROID_KEYSTORE_BASE64

在终端中执行：

**Linux / macOS:**
```bash
base64 -i open-hexo.jks | pbcopy
```

**Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("open-hexo.jks")) | Set-Clipboard
```

然后将复制的内容粘贴到 `ANDROID_KEYSTORE_BASE64` secret 中。

## 📱 配置 Android 项目

### 1. 修改 build.gradle

编辑 `android/app/build.gradle`，添加签名配置：

```gradle
android {
    // ... 其他配置

    signingConfigs {
        release {
            if (file("../key.properties").exists()) {
                def keystoreProperties = new Properties()
                keystoreProperties.load(new FileInputStream(file("../key.properties")))
                
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            // ... 其他配置
        }
    }
}
```

### 2. 本地测试签名

创建 `android/key.properties` 文件（**不要提交到 Git**）：

```properties
storePassword=您的密钥库口令
keyPassword=您的密钥口令
keyAlias=open-hexo
storeFile=keystore.jks
```

将 keystore 文件复制到 `android/app/keystore.jks`

测试构建：

```bash
flutter build apk --release
```

## 🚀 使用 GitHub Actions

### 自动触发

当您推送带有 `v` 前缀的 tag 时，会自动触发构建：

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 手动触发

在 GitHub 仓库的 **Actions** 页面，选择 "Build Signed APK" 工作流，点击 "Run workflow"。

## 📦 发布流程

1. 更新 `pubspec.yaml` 中的版本号
2. 提交更改并打 tag：
   ```bash
   git add .
   git commit -m "Release v1.0.0"
   git tag v1.0.0
   git push origin main --tags
   ```
3. 等待 GitHub Actions 完成构建
4. 在 Releases 页面查看发布的 APK

## ⚠️ 安全提示

- **永远不要**将 keystore 文件或 key.properties 提交到 Git
- 确保 `.gitignore` 包含以下内容：
  ```
  # Android signing
  android/key.properties
  android/app/keystore.jks
  *.jks
  *.keystore
  ```
- 定期备份 keystore 文件到安全位置

## 🔍 故障排查

### 构建失败：找不到签名配置

检查 `key.properties` 文件路径和内容是否正确。

### 签名失败：口令错误

确认 GitHub Secrets 中的口令与创建 keystore 时设置的一致。

### APK 无法安装

- 确认使用的是签名的 release 版本
- 检查设备是否允许安装未知来源应用

## 📚 相关文档

- [Flutter 官方文档 - 签名应用](https://docs.flutter.dev/deployment/android#sign-the-app)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
