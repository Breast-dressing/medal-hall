# AI 协作规则

- 本项目用 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 编译和测试；本地不跑 Xcode。改完代码 push，读 Build & Test 的测试报告再修。
- 新功能必须带测试；能用逻辑测试验证的不写成 UI 测试；UI 测试按条件等待，不用 sleep 固定等。
- 删测试只有三种理由：功能已删除、和另一个测试完全重复、已被更便宜的测试覆盖；删测试、改断言的预期值都要在提交里写明理由。
- 有意改了界面：手动运行 Build & Test 再跑一次确认变绿，并说明改了哪些页面。
- 部署只走 git → CI；MCP 只用来查数据、看日志、排查问题。
- 本仓库的工具链固定在 Xcode 27.2 / iOS 27.2 SDK（见 `.ios-ci.yml`）。GitHub 托管的 `macos-26` 镜像只装到 Xcode 26.6，因此 `.github/workflows/build-test.yml` 直接复用中央仓库的脚本与 composite action（`@df71d60 # v1.1.0`），但运行在带 Xcode 27.2 的 `xcode-27` 镜像上。
- 更多细节见 ios-ci-workflows 的 Skill：skills/ios-ci-workflows/SKILL.md。
