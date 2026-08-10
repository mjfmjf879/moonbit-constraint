# moonbit-constraint

项目仓库：[GitHub](https://github.com/mjfmjf879/moonbit-constraint) · [GitLink](https://gitlink.org.cn/mjfmjf/moonbit-constraint)

面向排班、资源分配、数独、配置生成和组合优化的 MoonBit 有限域约束求解器。

当前版本提供整数区间域、命名变量、等式/不等式约束、`AllDifferent`、`Sum`、`Element`、解空间枚举和 MRV（最小剩余值）分支。求解器保持纯 MoonBit 实现，没有外部运行时依赖，适合作为库嵌入命令行工具、服务端或领域应用。

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

## 设计边界

第一阶段优先保证模型表达能力、可测试性和可读的求解过程。当前搜索采用确定性的 MRV 分支，并在每个节点检查已加入的约束；后续版本将把域传播、冲突解释、重启、优化目标和增量求解拆为可替换策略。表约束、调度建模辅助 API 以及 SAT/SMT 互操作属于长期扩展方向。

## 项目来源与许可证

这是原创 MoonBit 实现，不复制第三方求解器源码。算法设计参考有限域约束编程的公开教材与通用思想，代码、测试和文档均由本项目独立维护。项目使用 Apache-2.0 许可证。

## 开发

需要 MoonBit 0.10.3 或更新版本。提交前执行：

```text
moon check --deny-warn
moon test --deny-warn
moon fmt --deny-warn
moon info --deny-warn
```
