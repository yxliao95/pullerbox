# 架构规范

## 1. 目标与范围

本规范定义应用的**分层结构、依赖方向、职责边界与命名规则**，用于确保：

* 业务复杂度增长时仍可维护
* 后续无痛接入真实蓝牙与持久化
* provider 成为唯一业务真相源

---

## 2. 技术栈与约束

* Flutter 2.0 及以上
* Riverpod 3.x
* Dart null safety

---

## 3. 项目结构

```text
lib/
├── main.dart
├── src/models/
├── src/services/
├── src/providers/
├── src/views/
├── src/routing/
├── src/theme/
└── src/utils/
```

### 单向依赖关系

```text
views → providers → services → models
```

### 明确禁止

* services 依赖 providers
* models 依赖 services / providers
* views 直接调用 services
* views 直接执行 IO、副作用

### 允许的例外

* utils 可被任意层使用
* utils 不得反向依赖业务类型

---

## 4. 分层职责

### 4.1 models 层

* 仅包含值对象与业务枚举
* 必须可序列化
* 不包含 IO、Riverpod、插件
* 字段尽量不可变，必要时提供 copyWith
* 时间字段统一 UTC 或显式时区

---

### 4.2 services 层

定位：**数据源与副作用**

示例：

* FakeForceMeterService
* BluetoothForceMeterService
* HistoryStorageService

规范：

* 对外仅暴露抽象接口或最小 API
* 所有 stream 必须支持取消订阅
* dispose 后不得继续产出数据

---

### 4.3 providers 层

定位：**业务编排与状态机**

* 将 service 数据转为 UI 状态
* 组合多个数据源
* 不依赖 BuildContext
* 副作用必须下沉到 services
* 状态可预测，同输入同输出

---

### 4.4 views 层

只允许：

* UI 展示
* 用户交互事件分发
* 少量本地 UI 状态

禁止：

* 业务逻辑
* 蓝牙或存储操作

---

## 5. 命名规范

* 文件名：snake_case
* 类名：UpperCamelCase
* 变量 / 方法：lowerCamelCase
* 私有成员：单下划线 `_`

Provider 命名建议：

* xxxServiceProvider
* xxxControllerProvider
* xxxStateProvider
* xxxStreamProvider

---

## 6. 页面拆分规范

```text
src/views/
├── pages/
├── widgets/
└── components/
```

每个页面至少拆分为：

* Page：页面壳
* View：布局
* Widgets：可复用组件
