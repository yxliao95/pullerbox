# 测试规范

## 1. 测试目标

测试不是为了覆盖率，而是：

* 锁死业务语义
* 锁死状态机转移
* 锁死关键数值逻辑

确保接入真实蓝牙或重构 provider 时不引入行为回退。

---

## 2. 合并前最低门槛

* flutter analyze 无 error
* flutter test 无 error
* 核心 provider 至少 1 条主流程测试
* 新 provider 必须新增测试
* 状态机或指标逻辑变更必须更新测试

---

## 3. 测试目录结构

```text
test/
├── models/
├── services/
│   └── fake/
├── providers/
├── utils/
└── helpers/
```

规则：

* 文件名与被测文件一致，加 `_test.dart`
* helpers 只能被 test 引用

---

## 4. models 层测试

重点：稳定性与可序列化性

必须覆盖：

* 构造边界值
* copyWith 行为
* toJson / fromJson 不丢信息
* 时间字段时区约定

禁止：

* mock provider / service
* 在 model 中引入测试逻辑

---

## 5. services 层测试

关注：

* 数据生成
* 时间
* 随机性
* 资源释放

Fake service 必须：

* 可注入时间源
* 可注入 Random 或固定 seed
* dispose 后停止产出数据

禁止：

* 真实插件或平台通道
* 依赖 Future.delayed 控制时间

---

## 6. providers 层测试

### 原则

* 使用 ProviderContainer
* 显式 override 所有 services
* 显式触发事件

### 必测内容

* 初始状态
* 合法状态转移
* 非法状态转移
* 指标更新逻辑

训练状态机至少覆盖：

* idle → preparing → running → finished
* running → paused → running
* 非 running 状态拒绝采样

---

## 7. AsyncValue 测试规范

* 显式断言 loading / data / error
* error 必须是可理解的业务错误
* 禁止使用 `.value!`

---

## 8. 时间与异步测试

* 禁止依赖真实时间
* 使用 fake_async 或 clock abstraction

原则：推进时间，而不是等待时间。

---

## 9. UI 测试边界

当前阶段不强制 widget test，但要求：

* widget 不包含业务逻辑
* 复杂判断已在 provider 测试中覆盖

---

## 10. 测试代码质量

* 每个 test 表达单一语义
* 禁止魔法数字
* 失败信息应直接定位问题
