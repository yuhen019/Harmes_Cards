# Hermes Cards · 软件测试报告

> 日期：2026-10-25（Windows 端验收）｜ 2026-10-26（Android 端适配回归，见第八节）
> 被测版本：Windows Release + Android 适配（PRD v1.3 对应实现）
> 测试方：软件开发团队（需求评审 + 代码审查 + 自动化测试）
> 测试依据：《卡片学习工具_软件需求文档.md》v1.3
>
> **最新结论（2026-10-26 Android 回归轮，含 KI-01 修复后复验）：自动化 57/57 全绿，`flutter analyze` 0 error 0 warning；Android 适配验收口径 10/10 全部闭环（唯一偏差 KI-01 已修复并复验通过），详见第八节。**

---

## 一、测试总览

| 维度 | 方法 | 结果 |
|------|------|------|
| 需求级测试 | PRD v1.3 逐条对照实现走查 | 发现 **12** 项偏差/缺失（P0×4 的衍生、P2×8） |
| 代码级测试 | 自动化测试 **39 项**（`tool/test_suite.dart` 纯 Dart 24 项 + `test/guardrails_test.dart` 护栏 16 项，其中 1 项两阶段断言） | **通过 25，失败 14** |
| 静态分析 | `flutter analyze` | 0 error（仅 const 样式建议） |

**总体结论：初测不建议发布（4 个 P0）。→ 2026-10-25 晚已全部修复，54/54 复测全绿，详见第七节。**

---

## 二、P0 严重缺陷（核心链路，必须修复）

### BUG-01 复习后卡片字段大面积丢失（数据损坏级）

- **位置**：`lib/services/fsrs_scheduler.dart` `review()` 末尾重建 `CardItem`
- **现象**：复习任意一张卡后，`context / source / flipped / enabled / againCount / suspended / recordingPath` 全部重置为默认值
- **证据**：A6a–f 六项全败——复习后 `context=null`、`flipped=false`、`enabled` 被复活为 `true`、`againCount=0`、`suspended=false`
- **连锁后果（这是最严重的一点）**：
  - **C3 Leech 护栏形同虚设**：连错 4 次当下会弹窗（内存对象被改过），但落盘的是 `suspended=false, againCount=0` 的新对象（B5b 失败）→ 重启后顽固卡复活，待处理列表为空（B5c 失败）
  - 学习页答案面的**语境/来源在第一次复习后永久消失**（C4 被破坏）
  - 翻转卡复习一次就**悄悄变回正向**（C5 被破坏）
  - 待启用卡一旦被复习会脱离 L5 管控
- **修复建议**：`review()` 改为复制原卡全部字段，仅覆盖 FSRS 字段（`stability/difficulty/retrievability/reps/lapses/due/state/updatedAt`），或给 `CardItem` 加 `copyWith`

### BUG-02 新卡被重复计入待复习和学习队列

- **位置**：`fsrs_scheduler.dart isDue()` 对 `state=='new'` 返回 `true`；`app_state.dart _dueAll()` 未排除新卡
- **现象**：
  - 首页「今日待复习」数字包含全部已启用新卡（B1a：3 张新卡 → 待复习显示 3）
  - 学习队列 = `dueCards() + newCards()`，**每张新卡出现两次，要学两遍**（B1b：队列 6 张去重后 3 张）
  - C8「只清复习」模式混进新卡（B3 失败）
  - C1 积压统计被新卡虚增，可能误触发或误解除积压保护
  - 卡包详情页「待复习」统计同样虚高
- **修复建议**：`isDue()` 仅对 `learning/review` 状态判断到期；`_dueAll()` 增加 `c.state != 'new'` 过滤

### BUG-03 C5 卡片翻转完全无效

- **位置**：`lib/models/card_item.dart flip()`
- **现象**：`flip()` 同时交换 `front/back` 字段**并**翻转 `flipped` 标志，而 `questionFace/answerFace` 又按 `flipped` 二次交换——双重反转等于没翻（A7：flip 前后提问面都是「苹果」）
- **修复建议**：二选一——要么交换字段，要么只翻标志位。建议只翻标志位（保留原始录入方向，可追溯）

### BUG-04 C6 学习步进设置不生效

- **位置**：`app_state.dart setLearningSteps()` 只写设置，从未同步给 `scheduler.learningSteps`；`graduatingIntervalDays / easyIntervalDays` 保存后无任何消费方
- **现象**：设置里把新卡步进 1m 改成 30m，Again 后到期时间仍是 1 分钟（B8：实际 1 分钟）
- **违反需求**：PRD 3.7.2「改后立即对新卡生效」
- **修复建议**：`_loadSettings` 与 `setLearningSteps` 中同步 `scheduler.learningSteps = [step1, step2]`；毕业/简单间隔要么接入调度器，要么从设置页撤下

---

## 三、P1 算法偏差（不影响使用，影响调度精度）

### BUG-05 FSRS 可提取率 R 的 elapsed 基准取错
- **位置**：`fsrs_scheduler.dart review()` 中 `elapsed = t.difference(card.due!)`
- **问题**：FSRS 的 elapsed 应为**距上次复习**的天数，当前用的是**逾期天数**。距上次复习 30 天 / 逾期 10 天的卡，参考实现 R≈0.58，当前算得 R=0.90（A3）→ 高估记忆留存，稳定性更新偏乐观，间隔会越拉越长
- **修复建议**：用 `t.difference(card.updatedAt)`（updatedAt 在每次复习时刷新，即上次复习时间）

### BUG-06 FSRS 难度更新公式与参考实现不符
- **位置**：`_difficultyAfterSuccess()`
- **问题**：① `exp(1 * (3 - 1))` 把系数 w5(1.2298) 硬编码成 1；② 用 `(d + Δ + target) / 2` 的自造平均代替标准的「线性阻尼 → 均值回归」两步；③ FSRS-4.5 权重下 `D0(good)` 计算为负值被截断到 1.0，新卡 Good/Easy 的难度区分度丢失
- **影响**：难度值与 Anki/参考实现不可比，但因 w7 权重小且单调性正确（A4 通过），实际调度仍可用
- **修复建议**：对照 open-spaced-repetition/fsrs4anki 参考实现重写难度更新

---

## 四、P2 需求未落地（功能缺失，非崩溃性）

| # | 需求 | 现状 | 证据 |
|---|------|------|------|
| BUG-07 | C7 超预算提示「今天够了，明天再来」 | `isOverBudget()` 定义了但**全工程无调用**，提示从未出现 | Grep 仅 app_state 定义处 |
| BUG-08 | C1 积压恢复阈值 60（迟滞） | 实现为 >150 暂停、≤150 即恢复，**无迟滞带**，积压 149↔151 间抖动会反复横跳 | `newPausedByBacklog` 单阈值 |
| BUG-09 | 3.1 牌组创建/重命名/删除/归档 | 模型有 `archived` 字段、服务有 `deleteDeck`，但**无任何 UI 入口**；牌组只能由导入间接创建 | deck_screen/home 无操作 |
| BUG-10 | 3.2.1 手动录入 + 卡片编辑器 | 未实现；连带 C3 顽固卡弹窗的「改写」无法直达编辑器（当前「改写」= 仅恢复重置，名不符实） | 无 editor 屏 |
| BUG-11 | C5 学习页「一键翻转」按钮 | 学习页只有「已翻转」徽标，无翻转操作入口；且 BUG-03 使翻转本身无效 | study_screen 走查 |
| BUG-12 | 3.6 标签与搜索 | 卡片有 tag 字段，但无搜索页、无按标签组队学习 | 无相关屏 |

> 说明：开口卡录音（L1）、音频（L2）按 PRD 迭代规划属 M2，不计入缺陷。

---

## 五、测试通过项（质量良好的链路）

| 链路 | 通过项 |
|------|--------|
| **CSV 导入解析** | 模板自解析 4/4；中文表头别名；UTF-8 BOM / UTF-16LE BOM；分号分隔自适应；引号内逗号/转义 |
| **文本快捷解析** | 多 `!` 只切首个；中文 `！`/`；`/换行分卡 |
| **JSON 存储** | 落盘/读回一致；损坏文件容错；多实例写前合并（43 张互不丢失） |
| **手动同步合并** | 差异预览与实合一致；较新者胜出；本地较新不倒退；日志按 id 并集；高版本包拒绝并提示升级 |
| **C1 积压暂停** | >150 暂停新卡、提示文案正确 |
| **C2 断卡恢复** | ≥3 天识别、新卡清零、「回来就好」温和文案 |
| **C3 Leech 计数** | 连错计数累计正确（仅落盘环节被 BUG-01 破坏） |
| **L5 分批释放** | 42 张启用 20；手动释放一批 28；待启用卡不进学习队列 |
| **FSRS 基本流** | 新卡 Good→review、Again→learning(≈1m)；难度单调性正确 |

---

## 六、修复优先级建议

| 优先级 | 项 | 理由 |
|--------|-----|------|
| 🔴 立即 | BUG-01（字段丢失） | 数据损坏级，每复习一张卡都在丢数据，且废掉 C3/C4/C5 三条需求 |
| 🔴 立即 | BUG-02（新卡重复） | 用户首日就会遇到「一张卡学两遍」 |
| 🟠 高 | BUG-03 / BUG-04 | C5/C6 两项 M1 必做护栏失效 |
| 🟡 中 | BUG-05 / BUG-06 | 调度精度，建议连 BUG-01 一起在 fsrs_scheduler 一次修好 |
| 🟢 规划 | BUG-07~12 | 功能补齐，排入 M1.1 |

**复测要求**：BUG-01~04 修复后，重跑 `dart run tool/test_suite.dart` 与 `flutter test test/guardrails_test.dart`，须全绿（39 项）方可验收。

---

## 附录：测试资产

| 文件 | 用途 |
|------|------|
| `hermes_cards/tool/test_suite.dart` | 纯 Dart 测试（FSRS / 解析 / 存储 / 同步），`dart run` 可重复执行 |
| `hermes_cards/test/guardrails_test.dart` | 护栏测试（AppState 级），`flutter test` 执行 |
| `hermes_cards/tool/check_csv.dart` | CSV 导入预检工具（导入任何文件前可先跑） |

---

# 七、修复与复测（2026-10-25 21:55，全部 12 项已修复）

## 修复清单

| # | 修复内容 | 关键改动 |
|---|----------|----------|
| BUG-01 ✅ | 复习字段丢失 | `fsrs_scheduler.review()` 改为全字段复制，仅覆盖调度字段（context/source/flipped/enabled/againCount/suspended/recordingPath 全部保留）；C3 Leech 落盘失效随之修复 |
| BUG-02 ✅ | 新卡重复计入 | `isDue()` 对 `state=='new'` 返回 false，新卡只走新卡队列；首页待复习、C8、C1 积压统计、卡包统计全部恢复准确 |
| BUG-03 ✅ | 翻转无效 | `flip()` 只翻 `flipped` 标志，不再交换字段（消除双重反转，保留原始录入方向） |
| BUG-04 ✅ | 步进设置不生效 | `_loadSettings`/`setLearningSteps` 同步 `scheduler.learningSteps`；新增 `graduatingIntervalDays/easyIntervalDays` 接入调度器（新卡 Good/Hard 按毕业间隔、Easy 按简单间隔） |
| BUG-05 ✅ | R 的 elapsed 基准 | 改用 `now - card.updatedAt`（距上次复习），A3 实测 R=0.766 与参考值一致 |
| BUG-06 ✅ | 难度公式 | 按官方 Wiki 重写为 FSRS-4.5 线性式 `D0(G)=w4-(G-3)*w5` + `D'=w7*D0(3)+(1-w7)*(D-w6*(G-3))`；同时修正成功/失败稳定性公式（原来也非 4.5 参考式） |
| BUG-07 ✅ | C7 超预算提示 | 首页今日卡下方接入：超预算显示「今天够了，明天再来 🌙」 |
| BUG-08 ✅ | C1 迟滞 | 新增 `_backlogPaused` 状态（>150 暂停、<60 恢复），持久化到设置，跨重启保留 |
| BUG-09 ✅ | 牌组管理 | 卡包页菜单：重命名/归档/删除（删除有确认）；首页「新建」入口（名称+emoji） |
| BUG-10 ✅ | 编辑器/手动录入 | 新增 `card_editor_screen.dart`（正反面/语境/来源/标签/翻转开关/超9词提示）；卡包页「+」手动录入、点卡片即编辑；C3 顽固卡「改写」直达编辑器 |
| BUG-11 ✅ | 学习页翻转按钮 | 卡片面右上角新增 swap 按钮，即时翻转并保存 |
| BUG-12 ✅ | 标签与搜索 | 新增 `search_screen.dart`：全文搜索（正/反/语境/来源）+ 标签筛选 + 「学习这些卡片」组队学习；首页放大镜入口 |

**附带加固**：学习结束弹窗改为「先弹窗、后退出」，消除先 pop 再用已停用 context 的崩溃隐患；卡包列表显示翻转后的实际提问面。

## 复测结果（全绿）

- `dart run tool/test_suite.dart`：**34/34 通过**（含新增 A5a/A5b 难度精确值断言）
- `flutter test test/guardrails_test.dart`：**20/20 通过**（含新增 B9 迟滞、B10 毕业/简单间隔）
- 合计 **54/54 通过**；`flutter analyze` **0 error 0 warning**
- `flutter build windows --release` 编译通过，exe 已更新

**结论：本轮发现的 12 项问题全部闭环，可进入用户验收。**

---

# 八、Android 端适配回归（2026-10-26）

## 测试环境

| 项 | 值 |
|----|----|
| Flutter | 3.47.8 stable（Dart 3.13.7） |
| 被测代码 | Android 适配分支（Windows / Android 共用 `lib/` 代码路径） |
| 执行方式 | 桌面端 `flutter test`（widget/单元层）+ `dart run`（纯算法层）+ 代码级核对（平台分支） |

## 执行的测试组与结果

| 测试组 | 执行方式 | 用例数 | 结果 |
|--------|----------|--------|------|
| `tool/test_suite.dart` 纯 Dart 套件（A 组 FSRS 调度 16 项 / C 组导入解析 9 项 / D 组存储与同步 9 项） | `dart run` | 34 | **34/34 通过** |
| `test/guardrails_test.dart` B 组护栏（C1 积压保护 / C2 断卡恢复 / C3 Leech / C5 翻转 / C6 步进 / C7 时间预算 / C8 只清复习 / L5 分批释放，含 B9 迟滞、B10 毕业/简单间隔） | `flutter test` | 20 | **20/20 通过** |
| `test/widget_test.dart` widget 冒烟 | `flutter test` | 1 | **通过** |
| `test/mobile_layout_test.dart` 手机布局（360×800 与 320×568 渲染首页/学习/卡包/设置四个主页面，断言无溢出异常） | `flutter test` | 2 | **2/2 通过** |

- 合计 **57/57 通过，失败 0**；`flutter test` 全量耗时约 1 分钟
- `flutter analyze`：**0 error / 0 warning**（98 条 info 级 const 风格建议，不影响质量门禁）
- Windows 回归确认：上述全部用例覆盖的是两端共用代码路径（调度、解析、存储、护栏、布局），**Windows 端既有功能未被 Android 适配破坏**

## Android 平台适配验收口径核对表

| # | 验收口径 | 核对方式 | 证据 | 结论 |
|---|----------|----------|------|------|
| 1 | 数据目录 = 应用私有目录 | 代码核对 | `main.dart:14` 使用 `getApplicationDocumentsDirectory()`（Android 上为应用私有目录，无需存储权限） | ✅ |
| 2 | 文件选择 = SAF | 代码核对 | `file_picker ^8.0.0`（Android 端走系统 SAF 选择器），导入/恢复均经 `FilePicker.platform.pickFiles` | ✅ |
| 3 | 导出 = 系统分享 | 代码核对 | `share_plus ^9.0.0`，`settings_screen.dart:182` 移动端导出走 `Share.shareXFiles` 系统分享面板 | ✅ |
| 4 | 打开文件夹按钮在 Android 隐藏 | 代码核对 | 导出结果弹窗的「打开文件夹」已做桌面门控（`settings_screen.dart:341`，仅 Windows/macOS/Linux 显示）；设置页「数据位置」组内的同名按钮初测时未门控（KI-01），**已修复**：与 `:341` 写法一致的 `Platform.isWindows || isMacOS || isLinux` collection-if 门控，复验通过 | ✅（KI-01 已修复） |
| 5 | 字体 = 平台默认 | 代码核对 | `app_theme.dart:50` 仅 iOS/macOS 指定 PingFang SC，Android 为 `null`（平台默认字体） | ✅ |
| 6 | 首页网格窄屏自适应 | 代码核对 + 自动化 | `home_screen.dart` `LayoutBuilder`：宽度 <400 时 `childAspectRatio` 0.92（窄屏加高格子防溢出）；`mobile_layout_test` 360/320 宽度渲染通过 | ✅ |
| 7 | 帮助浮层点击展开 / 点空白收起 | 代码核对 | `help_tip.dart:98` 触摸端（Android/iOS）注入全屏 `GestureDetector`，点空白即收起；近底部自动向上展开防出屏 | ✅ |
| 8 | 320dp 布局无溢出 | 自动化 | `mobile_layout_test.dart` 320×568 极窄屏四页面渲染，无 RenderFlex overflow 异常，**通过** | ✅ |
| 9 | 正式签名 | 配置核对 | `android/key.properties` 已配置且指向真实 keystore（`D:\1.software\Android\hermes-keystore.jks`，已存在）；release 构建启用 V1+V2 签名；keystore 缺失时回退调试签名（防出包失败的工程兜底，注释明示） | ✅ |
| 10 | ABI 分包 | 配置核对 | `build.gradle.kts` `splits.abi` 启用，`arm64-v8a / armeabi-v7a / x86_64` 三包 + universalApk | ✅ |

## 本轮测试过程说明（环境排障记录）

- 首次 `flutter test` 三份测试文件全部加载失败：`Unable to connect to flutter_tester process: WebSocketException: Invalid WebSocket upgrade request`
- **根因**： shell 环境中 `HTTP_PROXY/HTTPS_PROXY=http://127.0.0.1:52003` 代理变量劫持了 flutter_tester 的 localhost WebSocket 握手，**属环境问题，非源码/测试代码缺陷**
- **处置**：取消代理变量并设 `NO_PROXY=localhost,127.0.0.1` 后重跑，全部通过。后续在本机跑 Flutter 测试需注意该环境变量

## 遗留问题（Known Issues）

| # | 级别 | 问题 | 位置 | 状态 |
|---|------|------|------|------|
| KI-01 | P2 | 设置页「数据位置」组的「打开文件夹」按钮未在 Android/iOS 隐藏，点击静默无效（`xdg-open` 兜底被 catch） | `lib/screens/settings_screen.dart` 数据位置组（对照 `:341` 导出弹窗已正确门控） | ✅ **已修复并复验通过**（见下） |

## KI-01 修复与复验记录（2026-10-26，第 2 轮回归）

- **修复内容**：`lib/screens/settings_screen.dart`「数据位置」组的「打开文件夹」按钮补上 `if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)` collection-if 门控（与同文件 `:341` 导出弹窗写法一致），Android/iOS 上不再渲染该按钮
- **复验方式与结果**：
  - 代码核对：门控位置与写法正确 ✅
  - `flutter analyze lib/screens/settings_screen.dart`：**0 error / 0 warning**（22 条 info 级 const 建议，不卡门禁）✅
  - 全量回归 `flutter test`：B 组护栏 20/20 + 冒烟 1/1 + 手机布局 2/2，**All tests passed** ✅
  - `dart run tool/test_suite.dart`：**34/34 通过** ✅
  - 合计 **57/57 全绿**，KI-01 闭环，无新增回归

**Android 端回归结论（终版）：自动化 57/57 全绿，验收口径 10/10 全部闭环，Windows 端无回归，Android 适配可进入真机验收。**
