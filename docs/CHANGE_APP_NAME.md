# 修改应用名指南

本文档说明如何修改 Open Hexo 应用的显示名称和应用标识。

## 📱 修改显示名称（应用名）

应用显示名称是用户在手机上看到的名字。

### Android

修改文件：`android/app/src/main/AndroidManifest.xml`

```xml
<application
    android:label="您的应用名"
    ...>
```

**当前值**：`Open Hexo`

## 🔧 修改应用标识（可选）

应用标识（Application ID）是应用的唯一标识符，用于区分不同应用。

### Android

修改文件：`android/app/build.gradle.kts`

```kotlin
defaultConfig {
    applicationId = "com.yourcompany.yourapp"
    ...
}
```

**当前值**：`com.ssssshql.open_hexo`

⚠️ **注意**：
- 修改 Application ID 后，需要重新签名
- 已安装的应用需要卸载重装
- 如果已上架应用商店，不能修改 Application ID

### 包名（Package Name）

修改包名更复杂，需要：
1. 修改目录结构：`android/app/src/main/kotlin/com/ssssshql/open_hexo/`
2. 修改 `AndroidManifest.xml` 中的 package 属性
3. 修改 Kotlin/Java 文件中的包名声明

建议保持当前包名不变。

## 📝 修改项目名称（可选）

项目名称用于代码和构建配置。

### pubspec.yaml

```yaml
name: your_app_name
description: 您的应用描述
```

**当前值**：
- name: `open_hexo`
- description: `A new Flutter project.`

## 🎯 快速修改应用名

如果只想修改手机上显示的应用名：

1. 打开 `android/app/src/main/AndroidManifest.xml`
2. 修改 `android:label` 的值
3. 重新构建应用：
   ```bash
   flutter clean
   flutter build apk --release
   ```

## 📋 完整修改清单

| 位置 | 文件 | 字段 | 当前值 | 说明 |
|------|------|------|--------|------|
| Android 显示名称 | AndroidManifest.xml | android:label | Open Hexo | 手机上显示的名字 |
| Android 应用ID | build.gradle.kts | applicationId | com.ssssshql.open_hexo | 应用唯一标识 |
| 项目名称 | pubspec.yaml | name | open_hexo | 项目包名 |
| 项目描述 | pubspec.yaml | description | A new Flutter project. | 项目描述 |

## 💡 建议

1. **应用显示名称**：可以随时修改，建议使用友好的名称
2. **Application ID**：一旦发布不建议修改
3. **包名**：保持不变，避免复杂重构

## 🔄 修改后需要做什么

1. **清理构建缓存**：
   ```bash
   flutter clean
   ```

2. **重新获取依赖**：
   ```bash
   flutter pub get
   ```

3. **重新构建应用**：
   ```bash
   flutter build apk --release
   ```

4. **测试应用**：
   - 卸载旧版本
   - 安装新版本
   - 检查应用名称是否正确

## ⚠️ 注意事项

- 如果已上架 Google Play 或其他应用商店，修改 Application ID 会导致无法更新
- 修改应用名后需要重新签名
- 建议在开发阶段确定好应用名称和 Application ID
