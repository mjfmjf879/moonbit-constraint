# 贡献指南

请先阅读 README。新功能应同时补充公开 API 文档、黑盒测试和可运行示例。

本项目使用 MoonBit 0.10.3。提交前在仓库根目录运行：

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt --warn
moon info
```

`moon fmt` 与 `moon info` 在当前工具链中没有 `--deny-warn` 参数，因此 CI 使用“格式化/生成后工作区无差异”作为等价的严格检查。
