# moonbit-constraint

面向组合配置、排班、资源分配与组合优化的纯 MoonBit 有限域约束求解库。

## 项目定位

`moonbit-constraint` 提供有限整数域、可组合约束、确定性搜索、诊断统计和应用级建模组件，不依赖外部求解器运行时。

## 核心能力

- 区间域、离散值域、域运算和边界操作。
- 等式/不等式、线性、`AllDifferent`、表约束、计数、极值、区间资源约束。
- MRV 等变量启发式、解枚举、节点预算、增量假设、诊断统计和确定性基准。
- 排班、序列配额、轮班、资源日程、日历任务、数独、N 皇后、图着色、背包、分配、覆盖和装箱模型。
- 路由、项目依赖、容量网络、时间线、制造调度、离散事件、风险情景、质量门禁和运行台账。

## 快速开始

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

## CLI、架构与质量门禁

```text
moon run cmd/main
moon run --target native cmd/benchmark
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt
moon info
```

求解流程为“有限域与模型 → 约束传播 → 启发式分支 → 完整赋值校验”；应用模块负责领域模型、结果渲染、校验报告和运行指标。基准原始结果见 [`BENCHMARKS.md`](BENCHMARKS.md)，CI 工作流见 [`.github/workflows/test.yml`](.github/workflows/test.yml)。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
