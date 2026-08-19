# 贡献指南

请先阅读 README。新功能应同时补充公开 API 文档、黑盒测试和可运行示例。

本项目跟随官方 stable MoonBit 工具链。提交前在仓库根目录运行：

```text
moon version --all
moon update
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run --target native cmd/benchmark
moon fmt --check
moon info
```

CI 在 Ubuntu、macOS 和 Windows 上执行同一组质量门禁；提交前请确认格式化和生成接口不会产生工作区差异。
