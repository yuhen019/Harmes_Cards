# Hermes Cards

> 替代 Anki 的卡片学习工具，一套 Flutter 代码覆盖 **Windows + Android**。
>
> **决定成败的不是生成能力，是限制能力。**

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47-blue?logo=flutter">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Windows%20%7C%20Android-success">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-yellow">
</p>

---

## 项目简介

**Hermes Cards** 是一个面向「真实学习场景」的间隔重复卡片工具，用一套 Flutter 代码同时产出 Windows 桌面版和 Android 手机版。

它解决 Anki 类工具的三大痛点：

1. **上手成本高** —— 卡片制作、模板配置、插件调优门槛高；
2. **容易崩盘** —— 积压几百张后直接放弃，工具变成心理负担；
3. **缺少场景** —— 通用工具不解决「我要练门店接待话术」这种具体目标。

所以本项目的设计重心不在"能生成多少张卡"，而在**如何防止用户放弃**——这正是内置 9 大防崩溃护栏的由来。

典型用例：小米之家销售用 P1 核心语块（142 张）练英语接待话术。

---

## 功能特性

### 间隔重复
- **FSRS 调度算法**：根据记忆强度动态计算下次复习时间
- 三档评分（Again / Good / Easy）+ 毕业间隔策略

### 9 大防崩溃护栏（核心）
| 编号 | 名称 | 作用 |
|---|---|---|
| C1 | 积压保护 | 积压超阈值时不再新增新卡 |
| C2 | 断卡恢复 | 中断后回来不惩罚，温和恢复 |
| C3 | Leech 处理 | 反复错的卡自动暂停，避免死磕 |
| C5 | 方向翻转 | 中→英 / 英→中 可翻转 |
| C6 | 步进 | 学习步骤间隔可调 |
| C7 | 时间预算 | 每日学习时长上限 |
| C8 | 只清复习 | 只清复习队列，不动新卡 |
| L5 | 分批释放 | 导入的卡默认只启用 20 张，每天自动释放一批，防一次性堆积 |

### 文档导入
- 支持 **CSV / Markdown / 纯文本**
- 自动识别 **UTF-8（含 BOM）/ UTF-16（LE/BE）/ GBK** 编码
- 中文表头别名兼容（正面 / 反面 / 语境……）
- 分隔符自适应（`,` / `;` / Tab）

### 其他
- **手动数据包同步**：导出/导入 JSON 数据包，多设备写前合并，防止互相覆盖
- **学习统计**：热力图、连续打卡、保持率
- **演示数据**：一键装载/清除，方便试用
- **双端一致**：Windows 与 Android 共用同一套业务逻辑

---

## 下载与安装

不打算自己编译？直接使用已发布的产物（[Releases](https://github.com/yuhen019/Harmes_Cards/releases/latest)）：

- **Android**：下载 `HermesCards-v0.3.0-arm64-v8a.apk`（绝大多数手机首选）；
  不确定 CPU 架构时用 `HermesCards-v0.3.0-universal.apk`
- **Windows**：下载 `HermesCards-v0.3.0-win-x64.zip`，解压后双击 `hermes_cards.exe`

> APK 已用正式 keystore 签名（v1 + v2）。用户数据存于应用私有目录，**卸载前请先导出备份**。

---

## 技术栈

| 层 | 选型 |
|---|---|
| 框架 | Flutter 3.47.8 / Dart 3.13.7 |
| 状态管理 | provider |
| 存储 | **JSON 单文件**（纯 Dart，无数据库依赖，跨端一致） |
| 文件选择 | file_picker（封装 `FilePick`，移动端 SAF 适配） |
| 分享 | share_plus（移动端「导出即分享」） |
| 图表 | fl_chart |
| 公式渲染 | flutter_math_fork |
| 编码兼容 | fast_gbk（GBK/GB2312 自动识别） |

> 存储早期用 sqflite，因桌面端缺 sqlite3 原生库导致 Windows 包打不开数据库，已迁移到 JSON 单文件。

---

## 目录结构

```
hermes_cards/
├── lib/
│   ├── main.dart                 # 入口
│   ├── models/                   # card_item.dart、deck.dart
│   ├── services/                 # app_state、database_service、fsrs_scheduler、
│   │                             # document_parser、template_service、sync_service、
│   │                             # file_pick、demo_data_service
│   ├── screens/                  # home、deck、study、import、settings、stats、
│   │                             # card_editor、search、main_shell
│   ├── theme/app_theme.dart      # 主题（薄荷绿）
│   └── widgets/help_tip.dart     # 悬浮问号说明
├── test/
│   ├── guardrails_test.dart      # 护栏体系 20 项
│   ├── widget_test.dart          # 冒烟 1 项
│   └── mobile_layout_test.dart   # 手机尺寸布局 2 项
├── tool/
│   ├── test_suite.dart           # 纯 Dart 单测 34 项
│   ├── check_csv.dart
│   ├── verify_import.dart
│   ├── verify_demo.dart
│   ├── export_templates.dart
│   └── gen_icons.py              # 生成 Android 图标
├── android/                      # Android 工程（签名、自适应图标、ABI 分包）
├── windows/                      # Windows 桌面工程（C++ runner）
├── docs/                         # PRD v1.4、测试报告、原型演示 HTML
├── imports/                      # P1 核心语块卡片素材（2 个 CSV，可直接导入）
├── templates/                    # 导入模板 CSV + 给 AI 读的导入规格
└── pubspec.yaml
```

---

## 本地运行

```bash
# 1. 拉依赖
flutter pub get

# 2. 运行
flutter run -d windows     # Windows 桌面版
flutter run                # Android（需连接真机或模拟器）
```

### 跑测试

```bash
# 注意：必须先 unset 代理，否则 flutter_tester 的 localhost WebSocket 握手会被劫持
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  NO_PROXY=localhost,127.0.0.1 flutter test

# 纯 Dart 单测（34 项）
dart run tool/test_suite.dart

# 静态分析
flutter analyze
```

当前状态：**57/57 全绿**，`flutter analyze` 0 error 0 warning。

---

## 构建与出包

### Windows

```bash
flutter build windows --release
```

产物在 `build/windows/x64/runner/Release/`。分发时只需：
`hermes_cards.exe` + `flutter_windows.dll` + `*_plugin.dll` + `native_assets.json` + `data/`
（**不要**把运行时的 `hermes_cards.json` / `.db` 打进去，那是用户数据）

### Android

```bash
# 需要 JDK 17 + Android SDK
export JAVA_HOME="/path/to/jdk-17"
export ANDROID_SDK_ROOT="/path/to/android-sdk"
flutter build apk --release
```

产物在 `build/app/outputs/flutter-apk/`，按 ABI splits 生成 4 个包：
- `app-arm64-v8a-release.apk`（手机首选）
- `app-armeabi-v7a-release.apk`（32 位老设备）
- `app-x86_64-release.apk`（模拟器）
- `app-release.apk`（universal 全架构）

> 签名配置在 `android/key.properties`（**已被 .gitignore 排除，不入库**）。
> 如需自行出包，请创建自己的 keystore 并填写该文件。

### 构建环境已知坑

1. **代理会劫持 flutter test** → 跑测试前 `unset HTTP_PROXY HTTPS_PROXY`
2. **不能并发跑两个 flutter 命令** → `engine.stamp` 冲突
3. **Gradle 内存** → 建议 `-Xmx3G -XX:MaxMetaspaceSize=1G`、`workers.max=2`、`parallel=false`、`kotlin.incremental=false`
4. **国内镜像要放在 `google()`/`mavenCentral()` 之前**，否则 Gradle 逐源超时，下载极慢
5. **Flutter Windows 的 Dart 代码在 `data/app.so`**（不在 exe），判断构建是否生效看 app.so 时间戳

---

## 免责与许可

- 本项目为个人学习工具，不提供任何形式的担保。
- 卡片数据存于应用私有目录，**卸载前请先导出备份**。
- 采用 [MIT License](LICENSE) 开源。

---

## 相关文档

- [软件需求文档（PRD v1.4）](docs/卡片学习工具_软件需求文档.md)
- [测试报告（57/57 全绿）](docs/Hermes_Cards_测试报告_2026-10-25.md)
