# AGENTS.md

用于连接蓝牙拉力计的训练应用，具备以下功能：蓝牙连接和实时读数显示、计时器训练、训练计划管理、历史数据记录
目前暂不支持实际蓝牙设备连接，使用模拟数据进行开发和测试。

## 项目架构设计

使用 Flutter2.0 及以上版本开发，采用 Riverpod3.x 作为状态管理方案。

```text
lib/
├── main.dart
├── src/models/     // 数据模型
├── src/services/   // 数据接口服务，目前使用fake数据模拟数据库
├── src/provider/   // 状态管理与业务逻辑，把 services 的结果组织成 UI 可消费的状态
├── src/view/       // 页面 UI 层
```

推荐的单向依赖关系：views → providers → services → models

禁止或应避免：
services 依赖 providers
models 依赖 services / providers
views 直接调用 services

## 开发时

- 使用 Flutter 进行跨平台开发。
- 每次更新完成后，修改内容以列表形式总结在 docs/agent_logs.md 文档末尾。使用中文。

## 规范及版本接口

- Riverpod 3 中移除的 valueOrNull 应该替换为 asData?.value。
- DropdownButtonFormField 已经不再推荐使用 value + onChanged 的组合，应该使用 initialValue 来代替 value。
- Unnecessary use of multiple underscores. Try using '_'.
- views 中的组件应该尽量拆分到独立的 widget 文件中，避免单个文件过大。
