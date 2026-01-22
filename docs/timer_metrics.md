# 指力板训练统计规范

## 0. 基本结构与记录

一次训练 Session 包含 (N) 次循环，循环编号 (i=1..N)。每次循环由锻炼段和休息段组成：

锻炼段时长 (X) 秒
休息段时长 (Y) 秒
采样间隔 (\Delta t=0.05) 秒

循环切分优先级如下：
以计时器时间表为主，若存在手动开始或暂停或继续的事件标签，则用事件时间戳修正循环锻炼段起点 (s_i)。事件只能修正 (s_i)，不得改变 (X,Y)。

所有表现与控制与力竭统计只使用锻炼段数据 (t\in[0,X))。休息段只用于未来扩展，不参与当前指标计算。

每次 Session 必须保存元数据：(N,X,Y,\Delta t)，每轮锻炼段起点 (s_i)，事件修正标记，规则版本号。

---

## 1. 发力阶段划分

每轮锻炼段包含发力准备阶段与发力持续阶段。统计时忽略准备阶段，只使用持续阶段。

由于持续阶段门槛依赖“当轮最大力量”，而你要求最大力量只用持续阶段计算，会产生循环依赖，因此采用两阶段固化法。

### 1.1 第 1 阶段：临时持续阶段

对第 (i) 轮锻炼段 (t\in[0,X))：

临时鲁棒最大力
[
M^{(0)}_i=\mathrm{quantile}(F_i(t),0.99),\ t\in[0,X)
]
临时门槛
[
\theta^{(0)}_i = 0.95M^{(0)}_i
]

进入持续阶段需要满足“连续 (\tau_{enter}) 秒都不低于门槛”。若不满足，按回退规则仅缩短连续时间，不降低门槛：

(\tau_{enter}\in{0.30,0.20,0.10,0.05}) 秒（依次尝试，直到成功）
对应连续采样点数为 ({6,4,2,1})。

定义临时进入时刻
[
t^{(0)}*{start,i}=\min{t:\forall u\in[t,t+\tau*{enter}],\ F_i(u)\ge\theta^{(0)}_i}
]
记录回退等级 (L_i) 为首次成功的 level。

临时持续阶段
[
S^{(0)}*i=[t^{(0)}*{start,i},X)
]

### 1.2 第 2 阶段：最终持续阶段（用于所有统计）

最终鲁棒最大力只用持续阶段计算：
[
M_i=\mathrm{quantile}(F_i(t),0.99),\ t\in S^{(0)}*i
]
最终门槛
[
\theta_i=0.95M_i
]
用同一回退规则（(\tau*{enter}) 集合不变）在锻炼段内重新求进入时刻 (t_{start,i})：
[
t_{start,i}=\min{t:\forall u\in[t,t+\tau_{enter}],\ F_i(u)\ge\theta_i}
]
最终持续阶段
[
S_i=[t_{start,i},X)
]

后续所有指标严格仅使用 (S_i) 上的数据。

---

## 2. 单轮指标（每次循环计算）

### 2.1 最大力量

第 (i) 轮最大力量定义为持续阶段鲁棒最大值：
[
\text{MaxStrength}_i = M_i
]

Session 最大力量：
[
\text{MaxStrength}_{sess} = \max_i M_i
]

### 2.2 最大控制力量

控制区间为持续阶段内满足 (F_i(t)\ge 0.95M_i) 的点集：
[
C_i={t\in S_i:\ F_i(t)\ge 0.95M_i}
]
最大控制力量定义为控制区间的中位数：
[
F_{ctrl,i}=\mathrm{median}_{t\in C_i}(F_i(t))
]

Session 最大控制力量：
[
F_{ctrl,sess}=\max_i F_{ctrl,i}
]

### 2.3 控制时间

定义控制可接受下限为最大控制力量的 95%，允许超过：
[
\phi_i = 0.95F_{ctrl,i}
]
控制时间为持续阶段内满足 (F_i(t)\ge \phi_i) 的总时长：
[
T_{ctrl,i}=\int_{t\in S_i}\mathbf{1}\big(F_i(t)\ge \phi_i\big),dt
]

### 2.4 控制循环数

掉出时间定义为持续阶段内低于 (\phi_i) 的累计时长：
[
T_{out,i}=\int_{t\in S_i}\mathbf{1}\big(F_i(t)< \phi_i\big),dt
]
若
[
T_{out,i}\le 0.5\ \text{s}
]
则该轮记为一次控制循环（值为 1），否则为 0。Session 控制循环数：
[
N_{ctrl}=\sum_{i=1}^{N}\mathbf{1}(T_{out,i}\le 0.5)
]

### 2.5 每轮代表力量（用于降幅）

[
A_i=\mathrm{mean}_{t\in S_i}(F_i(t))
]

---

## 3. 力竭信号（Session 级）

### 3.1 基准最大力量与阈值

基准力量取前两轮最大力量的 0.99 分位数对应的前 95% 力量数据集合，并求中位数：
[
B=\mathrm{median}\Big(\{F_i(t)\in S_i\ |\ F_i(t)\ge 0.95M_i,\ i\in\{1,2\}\}\Big)
]
力竭阈值（80%）：
[
\psi=0.8B
]

### 3.2 未达标轮判定（在持续阶段内）

若在 (S_i) 内存在连续 1.0 s 都满足 (F_i(t)<\psi)，则该轮未达标：
[
Fail_i=1
]
否则 (Fail_i=0)。

对应离散连续点数为 (K_{fail}=20) 点。

同时定义该轮首次连续低于阈值 1.0 s 的起点：
[
t_{low,i}=\min{t\in S_i:\forall u\in[t,t+1.0],\ F_i(u)<\psi}
]

### 3.3 力竭信号触发与记录（回溯）

当首次出现连续两轮未达标：
[
Fail_i=1\ \text{且}\ Fail_{i+1}=1
]
则认为出现力竭信号，并记录为：

力竭起始轮：
[
i_{fail}=i
]
力竭时间节点（该轮内秒数）：
[
t_{fail}=t_{low,i_{fail}}
]
可选全局时间戳：
[
T_{fail}=s_{i_{fail}}+t_{fail}
]

最大力量开始下降的判据即为力竭信号，因此“最大力量维持到第几轮”可由 (i_{fail}) 直接给出。

---

## 4. 力竭后力量表现

### 4.1 最低控制力量

搜索范围为力竭时间节点之后的所有数据 (\Omega)：

第 (i_{fail}) 轮：([t_{fail},X))
后续轮 (i>i_{fail})：各自持续阶段 (S_i)

在 (\Omega) 上用长度 (W=1) s 的滑动窗口 (w) 扫描。每个窗口计算：
[
\mu_w=\mathrm{mean}(F(t)\ \text{in}\ w),\quad cv_w=\frac{\mathrm{std}(F(t)\ \text{in}\ w)}{\mu_w}
]
稳定窗口条件：
[
cv_w\le 0.05
]
最低控制力量定义为所有稳定窗口均值的最小值：
[
F_{minctrl}=\min_{w:cv_w\le 0.05}\mu_w
]
若不存在稳定窗口，则该指标记为缺失并记录标志位。

### 4.2 循环间力量降幅（从力竭开始）

基准取 session 最大控制力量：
[
F_{ctrl,sess}=\max_i F_{ctrl,i}
]
从 (i\ge i_{fail}) 的每轮代表力量 (A_i) 计算降幅百分比：
[
D_i=1-\frac{A_i}{F_{ctrl,sess}},\quad i\ge i_{fail}
]
对集合 ({D_i}) 统计：
均值 (\mathrm{mean}(D_i))
最大值 (\max(D_i))
标准差 (\mathrm{std}(D_i))

---

## 5. 结算页输出与可保存项

建议结算页至少展示并保存以下字段：

Session 级：
(\text{MaxStrength}*{sess})
(F*{ctrl,sess})
(N_{ctrl})
力竭信号：(i_{fail})、(t_{fail})（以及可选 (T_{fail})）
(F_{minctrl})（及缺失标记）
降幅统计：(\mathrm{mean}(D),\max(D),\mathrm{std}(D))

循环级（用于详情页与复盘，也建议保存）：
每轮 (M_i, F_{ctrl,i}, T_{ctrl,i}, T_{out,i}, A_i, L_i, Fail_i)
以及 (t_{start,i})、可选 (t_{low,i})

保存时必须同时保存规则版本号与关键超参数：0.99 分位数、0.95 门槛、连续时长集合、控制容忍 0.5 s、力竭阈值 0.8、连续 1.0 s、稳定窗口 1.0 s 与 CV 阈值 0.05。
