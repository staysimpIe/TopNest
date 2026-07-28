# 顶栖（TopNest）项目重写提示词

## 角色

你是一名熟悉 Flutter Windows、Dart、Win32 API 和 Windows 11 桌面应用开发的高级工程师。

请在当前项目中完成“顶栖（TopNest）”。这是一个 Windows 11 顶部常驻的通用桌面组件容器，用户可以选择组件、添加或移除组件，并通过拖动调整组件位置。

当前版本只实现以下三个额度统计组件：

1. Codex
2. Gemini
3. Claude & GPT（数据来源为 Antigravity）

额度统计只是首批组件。后续可能继续开发音乐播放器、系统性能监控、网络状态、天气、时间日历和快捷操作等组件。因此，产品名称、公共布局和组件管理代码不能被限定为。

本次不要实现音乐播放器或其他未来组件，也不要设计复杂的动态插件系统。只需要建立简单、清晰、便于继续增加内置组件的结构。

## 一、项目定位

- 面向平台：Windows 11 x64
- 产品名称：顶栖（TopNest）
- Flutter 包名：`topnest`
- 可执行文件名：`TopNest.exe`
- 界面语言：简体中文
- 默认字体：Microsoft YaHei UI
- 主窗口形态：Windows 桌面顶部常驻组件栏

面向用户的窗口标题、托盘提示、设置标题和安装包名称统一使用“顶栖（TopNest）”，不能再出现旧产品名。

为控制本次改动范围，可以暂时保留以下内部技术标识：

- Flutter 包名 `topnest`
- 可执行文件名 `TopNest.exe`
- MethodChannel 名称 `topnest/appbar`

## 二、开发原则

- 不要过度设计、过度抽象或过度编码。
- 不要加入本次没有要求的功能。
- 不要引入 Riverpod、Bloc、Redux、数据库或复杂依赖注入框架。
- 优先使用 Flutter、Dart 和 Windows 原生能力。
- 所有界面文字、错误提示和代码注释使用简体中文。
- 所有源文件统一使用 UTF-8。
- 保留已经稳定的数据读取、AppBar、托盘和 DWM 毛玻璃行为。
- 组件显示配置与额度数据读取逻辑必须分离。
- 不允许使用模拟额度填充真实数据缺失状态。
- 不保存 Codex 或 Antigravity 的登录凭据。
- Token 和 CSRF Token 只能在内存中使用，不能写入日志或配置文件。

## 三、Git 和现有修改保护

当前工作区可能存在用户尚未提交的修改。开始前必须检查：

```powershell
git status --short
git diff
```

要求：

- 不得覆盖或丢失用户未提交的修改。
- 不得执行 `git reset --hard`。
- 不得使用会丢失工作区内容的 checkout 操作。
- 不得擅自创建提交、切换分支或重写 Git 历史。
- 如果现有修改与重写内容重叠，应分析后合并，不能直接覆盖。
- 必须保留 Codex 本地缓存和官方重置次数的正确语义。

## 四、顶部组件栏

主窗口要求：

- 位于主显示器顶部。
- 高度固定为 36 逻辑像素。
- 横跨主显示器宽度。
- 正确适配 Windows DPI。
- 始终置顶。
- 隐藏系统标题栏。
- 不允许调整大小。
- 不显示在任务栏。
- 背景支持全透明和毛玻璃。
- 使用 Windows AppBar API 占用桌面工作区。
- 显示器配置、DPI 或系统设置变化时重新计算位置。
- 当前只支持主显示器，不需要增加多显示器选择功能。
- 普通关闭操作只收起到系统托盘，不直接退出。

## 五、三个等宽组件槽位

顶部栏分为：

1. 主体组件区域
2. 右侧固定操作区域

主体组件区域包含三个横向等宽槽位。

布局规则：

- 先为右侧操作区保留固定宽度。
- 将剩余宽度平均分成三个组件槽位。
- 三个槽位始终等宽。
- 每个已启用组件占用一个槽位。
- 组件之间使用轻量分隔线。
- 不允许组件内容改变顶部栏高度。
- 不需要横向滚动。
- 不需要用鼠标滚轮切换或滚动组件。
- 文字过长时使用缩写、省略或 Tooltip。
- 组件内容不能挤掉右侧操作按钮。

右侧操作区域始终显示：

- 最后更新时间
- 立即刷新按钮
- 设置按钮
- 收起到托盘按钮

无论组件是否有数据，右侧按钮都必须存在。

## 六、组件自定义规则

当前组件库只包含：

- Codex
- Gemini
- Claude & GPT

默认布局：

1. 第一个槽位：Codex
2. 第二个槽位：Gemini
3. 第三个槽位：Claude & GPT

用户可以：

- 在设置中添加组件。
- 在设置中移除组件。
- 拖动已启用组件改变排列顺序。
- 将组件拖动到其他槽位。

约束：

- 最多启用三个组件。
- 同一种组件只能添加一次。
- 不允许重复组件。
- 添加组件时放入第一个空闲槽位。
- 移除组件后对应槽位变为空槽位。
- 如果只启用一个或两个组件，仍保留三个固定槽位。
- 其他组件不能因为空槽位而自动拉伸。
- 空槽位可以透明，也可以显示轻量的“未添加组件”。
- 添加、移除或排序后，顶部栏立即同步。
- 组件布局需要持久化，应用重启后恢复。

## 七、通用组件模型

公共组件架构必须面向通用桌面组件，不能把整个布局层绑定到额度模型。

建议定义：

```dart
enum DesktopWidgetType {
  codex,
  gemini,
  claudeAndGpt,
}
```

建议的数据职责：

- `DesktopWidgetType`：标识组件类型。
- `DesktopWidgetConfig`：描述组件类型、启用状态和槽位。
- `WidgetLayoutController`：负责添加、移除、交换、排序和保存。
- `WidgetRegistry`：将组件类型映射到对应 Flutter Widget。
- `WidgetSlot`：渲染顶部栏中的一个等宽槽位。
- `ComponentManagementPanel`：设置窗口中的组件卡片管理区域。

额度数据仍然使用独立的额度模型：

- `QuotaWindow`
- `QuotaSnapshot`
- `QuotaProvider`
- `QuotaController`

职责边界：

- Provider 只负责获取数据。
- `QuotaController` 只负责刷新和保存快照。
- `WidgetLayoutController` 只负责组件布局。
- UI 根据 `DesktopWidgetType` 查找对应的 `QuotaSnapshot`。
- Provider 返回顺序不能决定组件显示顺序。
- 组件排序不能改变 Provider 数据。

未来加入音乐播放器时，应只需增加新的 `DesktopWidgetType`、组件实现和注册映射，不需要重写整个顶部栏及组件管理页面。本次不要提前实现通用第三方插件加载、脚本系统或动态程序集。

## 八、三个额度组件

### Codex 组件

显示内容：

- 名称：Codex
- 周额度剩余百分比
- 周额度重置倒计时
- 官方可用重置次数
- stale 警告
- 不可用状态

Codex 当前不需要显示 5 小时额度。

### Gemini 组件

显示内容：

- 名称：Gemini
- 5 小时额度剩余百分比
- 5 小时额度重置倒计时
- 周额度剩余百分比
- 周额度重置倒计时
- stale 警告
- 不可用状态

数据来源为 Antigravity。

### Claude & GPT 组件

显示内容：

- 名称：Claude & GPT
- 5 小时额度剩余百分比
- 5 小时额度重置倒计时
- 周额度剩余百分比
- 周额度重置倒计时
- stale 警告
- 不可用状态

数据来源为 Antigravity。可以在 Tooltip 或设置卡片中标注数据来源，不要在 36 像素顶部栏中加入冗长说明。

## 九、额度视觉规则

- 剩余额度大于 50%：绿色。
- 剩余额度大于 20% 且不超过 50%：橙色。
- 剩余额度不超过 20%：红色。
- 没有百分比数据时显示 `--`。
- 没有重置时间时显示“未提供”。
- 超过重置时间后显示“等待刷新”。
- 百分比限制在 0～100。
- 百分比显示为整数。
- 倒计时使用等宽数字。
- 倒计时每秒更新。
- 组件内部采用紧凑单行布局。
- 不要把顶部组件改成多行大卡片。
- 完整错误和说明通过原生 Tooltip 展示。

## 十、刷新机制

- 应用启动后立即读取额度。
- 根据刷新间隔自动刷新一次真实数据。
- 支持点击按钮立即刷新。
- 同一时刻只允许一个刷新流程执行。
- Codex 和 Antigravity Provider 可以并行刷新。
- 倒计时每秒刷新，但不能每秒请求额度数据。
- 隐藏组件时可以继续刷新对应 Provider，避免频繁启停数据源。
- 组件排序不能触发无意义的额度请求。

失败处理：

- 如果已有旧数据，继续显示旧数据并标记为 stale。
- stale 状态显示警告图标。
- 鼠标悬停时显示错误原因。
- 如果没有旧数据，显示明确的不可用状态。
- 禁止用固定百分比、随机值或模拟数据代替真实额度。
- 错误信息中的长 Token、密钥或认证字符串必须隐藏。
- 错误文字过长时合理截断。

## 十一、额度数据模型

保留统一额度模型：

```dart
enum QuotaProviderType {
  codex,
  antigravity,
}
```

`QuotaWindow` 至少包含：

- `remainingPercent`
- `resetsAt`
- `hasData`

`QuotaSnapshot` 至少包含：

- `provider`
- `groupName`
- `updatedAt`
- `fiveHour`
- `weekly`
- `resetCreditsAvailable`
- `stale`
- `error`

需要提供：

- 百分比限制方法。
- UTC 时间解析方法。
- 不可用快照构造方法。
- 保留旧数据并更新 stale/error 的复制方法。

## 十二、Codex 数据读取

实现独立的 `CodexQuotaProvider`。

### 本地缓存优先

Codex 主目录默认为：

```text
%USERPROFILE%\.codex
```

搜索目录：

- `sessions`
- `archived_sessions`

读取规则：

- 递归查找 `.jsonl` 文件。
- 按最后修改时间倒序排列。
- 最多检查最近 20 个文件。
- 每个文件最多读取末尾 1 MiB。
- 禁止完整读取大型会话文件。
- 从文件末尾向前寻找最新有效额度事件。
- 单个文件失败后继续检查其他文件。

只识别以下事件：

- 外层 `type == "event_msg"`
- `payload.type == "token_count"`
- `payload.rate_limits` 存在

本地字段使用 snake_case：

- `primary`
- `secondary`
- `individual_limit`
- `used_percent`
- `window_minutes`
- `resets_at`

解析规则：

- 收集所有有效窗口。
- 选择 `window_minutes` 最大的窗口作为周额度。
- 剩余百分比为 `100 - used_percent`。
- 重置时间读取 `resets_at`。
- 快照更新时间优先读取事件外层 `timestamp`。
- 时间字段兼容 ISO 8601、秒级时间戳和毫秒级时间戳。

重要语义：

- 本地 `rate_limits.credits.balance` 是账户余额。
- `credits.balance` 不是可用重置次数。
- 绝对不能把 `credits.balance` 显示成“重置次数”。

### Codex app-server

官方重置次数通过 Codex app-server 获取。

查找可执行文件：

1. `%USERPROFILE%\.codex\.sandbox-bin\codex.exe`
2. 找不到时执行 `where.exe codex.exe`

启动：

```text
codex app-server --stdio
```

通过 JSONL 协议依次执行：

1. `initialize`
2. 发送 `initialized` 通知
3. 调用 `account/rateLimits/read`

初始化客户端信息可以使用：

- name：`desktop-widget-bar`
- title：`顶栖（TopNest）`
- version：`1.0.0`

请求超时时间约 12 秒。

完成后：

- 完成或取消待处理请求。
- 关闭 stdout 和 stderr 订阅。
- 终止 app-server 子进程。
- 不得残留后台进程。

app-server 响应支持：

- `rateLimits`
- `rateLimitsByLimitId`
- `primary`
- `secondary`
- `individualLimit`
- `usedPercent`
- `windowDurationMins`
- `resetsAt`
- `rateLimitResetCredits.availableCount`

解析规则：

- 收集主额度及按 limitId 返回的额度窗口。
- 选择 `windowDurationMins` 最大的窗口作为周额度。
- 剩余百分比为 `100 - usedPercent`。
- 官方可用重置次数只能读取 `rateLimitResetCredits.availableCount`。

### 缓存与 app-server 组合策略

每次刷新优先读取本地缓存。

- 找到有效本地缓存时，使用本地周额度。
- 第一次成功读取本地缓存后，额外调用一次 app-server 获取官方重置次数。
- 将重置次数缓存在 `CodexQuotaProvider` 实例内存中。
- 后续刷新继续使用本地周额度和内存中的重置次数。
- 不要每 60 秒重复启动 app-server。
- 第一次获取重置次数失败时，不影响本地周额度展示。
- 获取失败时显示“未提供”。
- 如果找不到有效本地缓存，则使用 app-server 作为兜底。

## 十三、Antigravity 数据读取

实现独立的 `AntigravityQuotaProvider`，同时为 Gemini 和 Claude & GPT 组件提供数据。

### 进程探测

通过 PowerShell 查询 Antigravity language server：

- 使用 `Get-CimInstance Win32_Process`。
- 进程名匹配 `language_server` 或 `language-server`。
- 命令行包含 `antigravity`。
- 读取 PID。
- 从命令行提取 `--csrf_token value` 或 `--csrf_token=value`。
- 查询超时时间约 5 秒。

如果没有找到进程，返回明确错误：

```text
Antigravity 未运行
```

### 端口探测

执行：

```text
netstat.exe -ano -p tcp
```

要求：

- 只处理 LISTENING 端口。
- 只处理对应 PID。
- 端口去重并排序。
- 查询超时时间约 5 秒。

### 本地接口请求

对候选端口依次尝试 HTTPS 和 HTTP，只允许访问 `127.0.0.1`。

优先调用：

```text
/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary
```

请求体：

```json
{"forceRefresh": true}
```

失败后调用旧接口：

```text
/exa.language_server_pb.LanguageServerService/GetUserStatus
```

请求体：

```json
{}
```

请求头：

- `Content-Type: application/json`
- `Connect-Protocol-Version: 1`
- 存在 CSRF Token 时设置 `X-Codeium-Csrf-Token`

网络约束：

- 连接超时时间约 3 秒。
- 响应超时时间约 4 秒。
- 仅允许 127.0.0.1 对应端口接受自签名证书。
- 不能对其他主机放宽证书校验。
- 使用完毕后关闭 HttpClient。

### 新接口解析

从 `response`、`summary` 或根对象读取 `groups`。

分组映射：

- 名称包含 `gemini`：Gemini
- 名称包含 `claude` 或 `gpt`：Claude & GPT
- 其他分组忽略

额度桶：

- 忽略 `disabled == true`。
- 剩余量读取 `remainingFraction` 或 `remaining.remainingFraction`。
- 将 0～1 的比例乘以 100。
- 重置时间读取 `resetTime`。

5 小时窗口描述匹配：

- `five`
- `5h`
- `5 hour`
- `session`

周窗口描述匹配：

- `week`
- `7d`
- `7 day`

描述可以组合 `bucketId`、`displayName` 和 `description`。没有明确标记时不要臆测窗口类型。

### 旧接口兼容

从以下路径读取模型：

```text
userStatus.cascadeModelConfigData.clientModelConfigs
```

分组规则：

- 名称包含 gemini：Gemini
- 名称包含 claude 或 gpt：Claude & GPT

读取：

- `quotaInfo.remainingFraction`
- `quotaInfo.resetTime`

窗口推断：

- 距离重置不超过 6 小时：5 小时窗口。
- 距离重置不少于 20 小时：周窗口。
- 不符合规则时不归类。
- 同组多个模型选择剩余额度更低的结果。

### 容错要求

- 即使只读取到一个分组，也要保留两个组件各自的数据入口。
- 缺失分组返回无数据快照。
- 不允许用另一个分组的数据填充缺失分组。
- Antigravity 接口属于内部接口，解析失败时显示明确错误。
- 禁止虚构额度数据。

## 十四、设置窗口

设置使用独立 Flutter 子窗口，不能覆盖在 36 像素顶部栏中。

窗口要求：

- 标题：组件栏设置。
- 无边框。
- 居中显示。
- 不进入任务栏。
- 始终置顶。
- 不允许调整大小。
- 同一时间只允许一个设置窗口。
- 再次点击设置时聚焦已有窗口。
- 设置窗口关闭后不影响顶部栏。
- 主窗口退出时一并关闭设置窗口。
- 主窗口和设置窗口使用 `desktop_multi_window` 同步设置。

设置弹窗，左侧为设置菜单，暂时分为通用、外观、组件管理

## 十五、通用管理

设置Codex等AI用量刷新间隔
设置是否自启动

## 十六、卡片式组件管理

页面最上方展示顶栖模拟效果，选中组件可以展示组件的效果，拖动进行排序

下方是组件卡片列表

设置窗口中的“组件管理”区域以卡片形式显示，每行两个：

- Codex
- Gemini
- Claude & GPT

每张卡片显示：

- 组件名称
- 组件样式
- 选中效果

数据来源说明：

- Codex：Codex 本地会话和 app-server
- Gemini：Antigravity
- Claude & GPT：Antigravity

交互要求：

- 点击卡片放入第一个空闲槽位。
- 再次点击从顶部栏隐藏。
- 最多启用三个组件。
- 用户可以拖动顶栖模拟区域改变顺序。
- 拖动时显示清晰的占位反馈。
- 拖动完成后点击保存进行生效。

## 十七、外观和启动设置

保留以下设置：

### 背景效果

- 全透明
- 毛玻璃

### 背景透明度

- 只在全透明模式显示。
- 范围 0～1。
- 20 个分段。
- 默认值 0.72。

### 毛玻璃强度

- 只在毛玻璃模式显示。
- 范围 0～1。
- 20 个分段。
- 默认值 0.55。

### 主题

- 跟随系统
- 浅色
- 深色

### 文字颜色

- 自动
- 深色文字
- 浅色文字

## 十八、配置持久化

继续使用 `shared_preferences`。

保留原有设置：

- `effect`
- `themeMode`
- `textColor`
- `opacity`
- `acrylicStrength`
- `autoStart`

新增组件布局配置：

- 三个槽位中的组件类型。
- 组件排列顺序。
- 空槽位信息。

可以保存固定长度列表，例如：

```json
["codex", null, "claudeAndGpt"]
```

要求：

- 配置格式简单、稳定。
- 不需要数据库。
- 没有组件配置时使用默认三个组件。
- 旧版本升级后保留原有外观和启动配置。
- 未知组件类型应安全忽略。
- 重复组件应自动清理。
- 损坏配置应回退到安全默认布局。
- 配置错误不能导致应用无法启动。

## 十九、系统托盘

托盘提示统一为“顶栖（TopNest）”。

左键单击：

- 显示顶部组件栏。

右键菜单：

- 显示组件栏
- 立即刷新
- 设置
- 退出

行为：

- 点击顶部栏收起按钮时隐藏到托盘。
- 普通窗口关闭时隐藏到托盘。
- 只有托盘菜单“退出”才真正退出。
- 退出时关闭设置窗口。
- 退出时注销 AppBar。
- 退出时销毁托盘图标。
- 退出时取消定时器和监听器。
- 最后关闭主窗口。

## 二十、原生 Tooltip

顶部栏只有 36 像素高，普通 Flutter Tooltip 容易被裁剪，因此继续使用 Windows 原生 Tooltip。

Flutter 侧：

- 使用 MouseRegion 监听进入、移动和离开。
- 鼠标进入约 350 毫秒后显示。
- 鼠标离开时隐藏。
- Widget 销毁时取消定时器并隐藏 Tooltip。

Windows 侧：

- 使用 Windows Tooltip 控件。
- Tooltip 保持 TOPMOST。
- 不激活主窗口。
- 支持 UTF-8 中文。
- 正确转换 Flutter 坐标和屏幕坐标。
- 正确处理 DPI。

Tooltip 可显示：

- 组件完整名称
- 数据来源
- 错误详情
- stale 状态说明
- 按钮功能说明

## 二十一、Windows AppBar

注册：

- 使用 `SHAppBarMessage(ABM_NEW, ...)`。

定位：

- 使用 `ABM_QUERYPOS`。
- 使用 `ABM_SETPOS`。
- 顶部边缘使用 `ABE_TOP`。
- 高度按照 36 逻辑像素和当前 DPI 计算。
- 使用 `SetWindowPos` 保持 TOPMOST。
- 使用 `SWP_NOACTIVATE`。

注销：

- 使用 `SHAppBarMessage(ABM_REMOVE, ...)`。

发生以下事件时重新定位：

- `WM_DISPLAYCHANGE`
- `WM_SETTINGCHANGE`
- AppBar 回调中的 `ABN_POSCHANGED`

## 二十二、Windows 毛玻璃

这是已经稳定的视觉和运行行为，必须保留现有技术路线。

### 浅色毛玻璃

使用：

- `DwmSetWindowAttribute`
- 属性 `DWMWA_SYSTEMBACKDROP_TYPE`
- 值 `DWMSBT_TRANSIENTWINDOW`

系统不支持时：

1. 将 DWM 背景恢复为 `DWMSBT_NONE`。
2. 回退到经典 Acrylic。

### 深色毛玻璃

使用：

- `SetWindowCompositionAttribute`
- `ACCENT_ENABLE_ACRYLICBLURBEHIND`

### 全透明模式

使用：

- `SetWindowCompositionAttribute`
- `ACCENT_ENABLE_TRANSPARENTGRADIENT`

### 禁止事项

- 不要使用 `DesktopAcrylicController`。
- 不要依赖 flutter_acrylic 初始化 DispatcherQueue。
- 不要改成可能在 CoreMessaging.dll 中异步崩溃的方案。
- 不要删除现有 DWM 路径。
- 不要在浅色最低毛玻璃强度下添加不透明白色 Flutter 背景层。
- 不要在延迟恢复效果时调用不稳定的 `windowManager.isVisible()`。
- 不要把已接受的毛玻璃替换成纯色背景。

## 二十三、Flutter 与 Windows 通信

继续使用 MethodChannel：

```text
topnest/appbar
```

至少支持：

- `register`
- `unregister`
- `reposition`
- `setEffect`
- `showTooltip`
- `hideTooltip`

`setEffect` 参数至少包括：

- `acrylic`
- `dark`
- `alpha`
- `red`
- `green`
- `blue`

Dart 侧使用独立的 `WindowsShellService` 封装 MethodChannel，不要在多个 UI 文件中散落原生调用。

## 二十四、开机启动

继续使用 `launch_at_startup`。

- 应用名称使用“顶栖（TopNest）”。
- 应用路径使用 `Platform.resolvedExecutable`。
- 开启时调用 enable。
- 关闭时调用 disable。
- 设置结果保存到 shared_preferences。

## 二十五、建议代码结构

建议结构如下，但不要为了完全匹配而创建大量只有几行的文件：

```text
lib/
  main.dart
  models/
    quota.dart
    desktop_widget_config.dart
  providers/
    quota_provider.dart
    codex_provider.dart
    antigravity_provider.dart
  controllers/
    quota_controller.dart
    widget_layout_controller.dart
  services/
    settings_service.dart
    windows_shell_service.dart
  ui/
    widget_bar.dart
    widget_slot.dart
    native_tooltip.dart
    settings_window.dart
    settings_panel.dart
    component_management_panel.dart
    widgets/
      codex_quota_widget.dart
      gemini_quota_widget.dart
      claude_gpt_quota_widget.dart
windows/
  runner/
    flutter_window.cpp
installer/
  topnest.iss
test/
```

如果部分文件内容较少，可以合理合并。重点是职责清晰，不是文件数量。

## 二十六、依赖约束

保留实际需要的最小依赖：

- flutter
- cupertino_icons
- window_manager
- tray_manager
- launch_at_startup
- shared_preferences
- desktop_multi_window

处理依赖时：

- 先确认现有依赖是否真实使用。
- 未使用依赖可以删除。
- 删除前确认不会破坏毛玻璃、托盘、设置子窗口和 Windows 构建。
- 不要为拖动排序引入大型第三方库。
- 优先使用 Flutter 自带的 `ReorderableListView` 或简单拖放能力。

## 二十七、测试要求

至少保留或增加以下测试。

### Codex app-server 解析

- 选择持续时间最长的窗口作为周额度。
- 正确计算 `100 - usedPercent`。
- 正确解析 `rateLimitResetCredits.availableCount`。
- 缺少字段时保持 null。
- 百分比限制在 0～100。

### Codex 本地 JSONL

- 正确识别 `event_msg/token_count/rate_limits`。
- 正确解析 snake_case 字段。
- 正确选择最长窗口。
- 正确解析事件 timestamp。
- 不把 `credits.balance` 当作重置次数。
- 无关事件返回 null。
- 损坏 JSON 不导致整体读取失败。

### Antigravity

- 正确解析 Gemini。
- 正确解析 Claude & GPT。
- 正确解析 5 小时和周窗口。
- 忽略 disabled 桶。
- 未标记的桶不能被臆测分类。
- 缺少一个分组时另一个分组不受影响。
- 正确将 remainingFraction 转换为百分比。

### 组件布局

- 默认启用三个组件。
- 默认顺序正确。
- 可以添加和移除组件。
- 同一种组件不能重复添加。
- 最多启用三个组件。
- 拖动后顺序正确。
- 只启用一个或两个组件时保留空槽位。
- 配置可以保存和恢复。
- 未知、重复或损坏配置能够安全清理或回退。

### Controller

- 同一时间不会重复刷新。
- Provider 可以并行刷新。
- 读取失败时保留旧数据。
- 旧数据正确标记 stale。
- 没有旧数据时生成不可用快照。
- Provider 返回顺序不影响组件显示顺序。

## 二十八、实施顺序

1. 将产品文案统一为“顶栖（TopNest）”。
2. 实现三个固定等宽槽位。
3. 实现组件添加、移除和拖动排序。
4. 实现卡片式组件管理设置。
5. 保留现有 Codex 和 Antigravity 数据语义。
6. 保留现有 AppBar 和 DWM 实现。
7. 格式化代码。
8. 执行静态检查和测试。
9. 环境允许时执行 Windows 构建。

建议命令：

```powershell
dart format lib test
flutter analyze
flutter test
flutter build windows --release
```

不要在没有实际执行的情况下声称检查、测试或构建成功。
