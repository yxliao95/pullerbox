# AGENTS.md

用于连接蓝牙拉力计的训练应用，功能包括：蓝牙连接与实时读数显示、计时器训练、训练计划管理、历史数据记录。当前阶段不接入真实设备，统一用模拟数据驱动开发与测试，后续可无痛替换为真实蓝牙实现。

## 1. 技术栈与约束

* Flutter 2.0 及以上版本
* Riverpod 3.x 作为状态管理
* Dart null safety
* 当前数据源：Fake services 模拟（后续替换为真实蓝牙与持久化存储）

## 2. 项目结构与单向依赖

```text
lib/
├── main.dart
├── src/models/       // 纯数据模型，序列化/反序列化与校验
├── src/services/     // 数据源：fake/bluetooth/storage 等
├── src/providers/    // 状态管理与业务编排，把 services 组织成 UI 可消费的状态
├── src/views/        // 页面与组件（只做展示与交互）
├── src/routing/      // 路由与导航（如果页面数开始增长就启用）
├── src/theme/        // 主题、间距、字号、颜色（建议尽早抽出来）
└── src/utils/        // 通用工具（严格控制规模）
```

推荐单向依赖关系：views → providers → services → models

禁止或应避免：

* services 依赖 providers
* models 依赖 services / providers
* views 直接调用 services
* views 直接进行持久化写入或蓝牙操作

允许的例外（必须写清原因）：

* utils 可被任意层引用，但不得反向引入业务层类型（避免 utils 变成垃圾桶）

## 3. 分层职责边界

### 3.1 models 层

* 只放“值对象”和“业务枚举”，不包含 IO、插件调用、Riverpod 引用
* 模型必须可序列化（即使当前阶段不落盘，也要为历史记录做准备）
* 对外暴露的字段尽量不可变（final），必要时提供 copyWith
* 时间统一使用 UTC 或明确记录时区（训练记录会跨设备同步的话尤为重要）

### 3.2 services 层

* 面向“数据源”和“副作用”，例如：

  * FakeForceMeterService：生成模拟力数据流
  * BluetoothForceMeterService：未来真实设备实现
  * HistoryStorageService：历史记录读写（未来）
* services 对外只暴露抽象接口或最小 API，避免泄漏实现细节
* 所有流式数据必须提供取消订阅与释放资源的机制（避免后台还在跑）

### 3.3 providers 层

* 负责业务编排与状态整形：

  * 把 services 的 stream 转成 UI 需要的状态对象
  * 组合多个数据源（例如：训练计时器状态 + 实时力数据 + 训练计划）
* provider 不做 UI 细节，不直接依赖 BuildContext
* provider 状态必须可预测：同输入同输出，副作用在 services

### 3.4 views 层

* 只做：展示、交互事件分发、简单的本地 UI 状态（例如 Tab index、滚动位置）
* 禁止：复杂业务逻辑、直接读写存储、直接操作蓝牙
* 大组件拆分：页面文件只保留页面骨架与布局，细组件下沉到 widgets/

## 4. 命名与文件组织

### 4.1 命名约定

* 文件名：snake_case
* 类名：UpperCamelCase
* 变量与方法：lowerCamelCase
* 私有标识：使用单个下划线 `_`，避免多重下划线
* provider 命名建议：

  * `xxxServiceProvider`（提供 service 实例）
  * `xxxControllerProvider`（业务控制器/状态机）
  * `xxxStateProvider`（纯状态，能不用就不用）
  * `xxxStreamProvider`（数据流）

### 4.2 页面与组件拆分规则

* 页面目录建议：

  * `src/views/pages/`
  * `src/views/widgets/`
  * `src/views/components/`（可选，放复用组件）
* 每个页面至少拆出：

  * `Page`（页面壳）
  * `View`（主体布局）
  * `Widgets`（可复用块）

## 5. 状态管理与 Riverpod 使用规范（3.x）

### 5.1 基本规则

* UI 读状态用 `ref.watch`
* 触发动作用 `ref.read(xxxProvider.notifier).action()` 或 controller 暴露方法
* 避免在 build 中写入状态（会导致循环重建）

### 5.2 AsyncValue 处理

* Riverpod 3 移除 `valueOrNull`，统一用 `asData?.value`
* UI 必须对 `loading/error/data` 三态显式处理，禁止直接 `.value!`
* 错误必须在 provider 内转换成可读的 error 类型或 message，UI 不做异常解析

### 5.3 生命周期与资源释放

* 涉及 stream/timer 的 provider 必须 `autoDispose`，并在 dispose 时清理资源
* 长连接（未来蓝牙）要有“显式连接/断开”动作，不靠隐式 watch

### 5.4 Dropdown 组件约定

* `DropdownButtonFormField` 避免 `value + onChanged` 的旧组合，使用 `initialValue`
* 状态更新通过 controller 方法或 provider notifier 统一入口，避免在 widget 内散落 setState

## 6. 训练域模型与状态机约束

为了后续支持“计时器训练 + 自由训练 + 历史记录”，建议尽早明确状态机边界：

* 训练会话（Session）必须有：

  * sessionId
  * startTime, endTime
  * samplingConfig（采样频率、窗口大小、是否模拟等）
  * metrics（最大力、控制时间、窗口统计等）
  * rawSamples 可选（初期可不存，后期再加）
* 训练状态机最少包含：

  * idle
  * preparing（倒计时/校准）
  * running
  * paused
  * finished
* 状态转换只能发生在 provider/controller 内，UI 只能发送事件

## 7. 数据模拟规范（当前阶段重点）

* Fake 数据源必须可配置：

  * 采样频率（Hz）
  * 噪声强度
  * 最大力范围
  * 力曲线模式（例如线性上升、阶梯、随机游走）
* 必须支持“可复现模式”：

  * 固定随机种子，保证测试稳定
* 模拟数据的“时间基准”必须来自同一处（避免 timer 与 stream 时间漂移）

## 8. 测试与质量门槛（建议最低要求）

* providers 层必须可单测：

  * 输入事件，断言状态与关键指标输出
* services 层至少有基础测试或可注入 fake clock/random
* 禁止在核心路径引入难测的单例与全局状态

最低门槛（每次合并前）：

* `flutter analyze` 无 error
* 关键业务 provider 的单测至少覆盖 1 条主流程

## 9. 日志与变更记录

* 每次更新完成后，必须把修改内容以列表形式追加到 `docs/agent_logs.md` 文档末尾，使用中文
* 日志至少包含：

  * 修改点
  * 影响范围（页面/模块）
  * 是否涉及数据结构变化（如有必须注明迁移方式）

## 10. 代码风格补充

* 优先使用组合而非继承
* 统一错误处理策略：不要把异常直接抛到 UI
* 避免过早抽象，但对“未来必替换”的模块（蓝牙、存储）必须先抽接口

## 11. 常见问题补充

* 使用 `ValueListenable/ValueListenableBuilder` 时必须显式引入 `package:flutter/foundation.dart`（避免未识别类型）
