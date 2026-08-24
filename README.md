# moonbit-constraint

面向组合配置、排班、资源分配与组合优化的纯 MoonBit 有限域约束求解库。
项目提供可组合的模型 API、确定性搜索、约束传播、诊断指标和应用级建模组件，适合嵌入命令行工具、测试夹具和领域应用。

## 项目定位

`moonbit-constraint` 将整数有限域、约束模型和可解释的搜索统计组合成一个小型约束编程内核。它不依赖外部求解器运行时，模型和求解器均由 MoonBit 实现；应用层可以直接复用数独、N 皇后、图着色、排班、资源日程、背包和分配等建模模块。

## 核心能力

- 区间域、离散值域、域交并差、区间画像与边界操作。
- 等式/不等式、线性约束、`AllDifferent`、`Element`、计数、极值、绝对值、距离、表约束、区间不重叠和累计资源约束。
- MRV、首次未赋值、最大约束度、域/度比启发式，以及升序、降序和中值优先取值策略。
- 解枚举、节点预算、传播轮次、求解统计、结构诊断、违约报告和确定性基准指标。
- 增量快照、临时假设求解、可逆域恢复、冲突核心报告和决策轨迹。
- 约束组合器、布尔关系、整数关系表、优化目标、Pareto 前沿和 CSV/文本模型辅助工具。
- 可直接运行的排班、序列配额、轮班模板、资源日程、日历任务、数独、N 皇后、图着色、拉丁方、幻方、背包、集合覆盖、装箱和分配模型。
- 面向生产流程的路由规划、项目依赖、容量网络、图算法、时间线分析、制造调度、离散事件模拟、风险情景、场景组合、质量门禁和运行台账。
- 提供矩阵/统计/文本/校验/报告等无外部依赖的应用基础设施，便于把求解结果接入 CLI、批处理和回归检查。

## 快速开始

将仓库作为 MoonBit 模块依赖后，可以按下面的方式创建模型：

```mbt check
///|
test {
  let model = @moonbit_constraint.new_solver()
  let left = model.add_variable(@moonbit_constraint.variable("left", 1, 9))
  let right = model.add_variable(@moonbit_constraint.variable("right", 1, 9))
  model.add_constraint(@moonbit_constraint.sum([left, right], 10))
  match model.solve() {
    Some(solution) => debug_inspect(solution.values, content="[1, 9]")
    None => fail("the model should be satisfiable")
  }
}
```

## CLI

仓库包含两个可运行入口：

```text
moon run cmd/main
moon run --target native cmd/benchmark
```

第一个入口运行最小模型示例；第二个入口运行固定的应用基准套件，输出纯文本和 Markdown 表格，并在存在未解决案例时以失败状态退出。

## 架构

```text
Domain / DomainProfile
        ↓
Variable + Constraint + Solution
        ↓
Solver：传播 → 启发式分支 → 完整赋值校验
        ↓
Builder / Diagnostics / Optimization / Model I/O
        ↓
Routing / ProjectPlan / CapacityNetwork / ResourceTimeline / Simulation
        ↓
QualityReview / ValidationReport / OperationalLedger / Domain Reports
```

底层求解器保持整数有限域模型的通用性；应用模块负责变量布局、约束构造、结果渲染、领域校验和可复现的运行指标。否定距离等非凸关系保留在完整赋值阶段校验，避免传播器产生不正确的剪枝。

## 基准

基准使用求解器自身的确定性工作计数（节点、传播、约束检查、剪枝和值域深度），减少不同机器时钟精度带来的噪声。运行：

```text
moon run --target native cmd/benchmark
```

当前一次本地运行的完整记录见 [`BENCHMARKS.md`](BENCHMARKS.md)；其中包含工具链、运行平台、原始 CLI 输出和复现命令。

## 测试

测试覆盖核心域运算、边界耗尽、线性/关系约束、解枚举、优化模型和应用场景，并包含 malformed input、矛盾模型、负数域、空解空间、容量边界、路由/图/流/时间线边界和节点预算等用例。跨模块集成测试还会验证制造调度、场景自检、资源指标、数据模式、文本适配以及基准回归检测。

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt
moon info
```

## CI

GitHub Actions 在 Ubuntu、macOS 和 Windows 上安装官方 stable MoonBit 工具链，并强制要求 `moonc >= v0.10.9`。流水线执行依赖更新、全目标 check/build/test、CLI 示例、格式检查、接口生成检查和基准回归。工作流位于 [`.github/workflows/test.yml`](.github/workflows/test.yml)。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
