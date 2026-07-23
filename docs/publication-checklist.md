# 首次公开发布清单

本清单区分“本地仓库已经可公开”和“托管平台已经正确配置”。后者需要仓库创建后
由维护者在 GitHub 完成，不能由本地测试结果替代。

## 创建仓库前

- `tests/verify.ps1` 在完整、非浅克隆中通过。
- `tests/run-gui-tests.ps1 -SoakSeconds 300` 通过，GDI 和 USER 增长均为零。
- 当前发行 EXE 与完成长时 GUI 压力测试的 EXE 哈希一致；若不一致，重新运行长测。
- `tests/reproducible-build.ps1` 连续两次产生相同 ZIP 和 SBOM 哈希。
- `git log --all --name-only` 不包含真实配置、维护会话或临时探针。
- `watchdog.ini` 和 `watchdog.maintenance.ini` 仍被忽略且哈希未改变。
- `VERSION`、主脚本文件版本、`CHANGELOG.md` 和标签完全一致。
- Release 说明明确列出尚未完成的物理 Windows、DPI、多显示器或高对比度组合。

## GitHub 仓库设置

1. 创建空仓库，不自动生成 README、许可证或 `.gitignore`，避免无关合并提交。
2. 先推送 `main`，确认 CI 全部通过，再推送版本标签。
3. 在“Settings → General”启用 Issues，按需关闭 Discussions 和 Wiki。
4. 在“Settings → Code security”启用 Dependabot alerts、Dependabot security updates、
   Secret scanning、Push protection 和 Private Vulnerability Reporting。
5. 为 `main` 建立规则集：禁止强制推送和删除，要求 Pull Request、讨论已解决、
   分支保持最新，并要求 CI 的 `verify` 检查通过。只有一名维护者时审批数设为零，
   避免作者无法批准自己的 PR；增加第二名维护者后再启用 CODEOWNERS 审批。
6. 保留 Actions 的默认最小权限；发布工作流只使用文件内显式声明的 `contents`、
   `id-token` 和 `attestations` 权限。
7. 检查 Actions 允许使用仓库中已经固定完整提交 SHA 的第三方 Action。
8. 在仓库 About 中填写简洁描述、Windows／AutoHotkey 主题和实际许可证。

## 首个 Release

- 标签只指向已经通过完整验证的提交，且标签名为 `v<VERSION>`。
- Release 工作流重新执行全历史扫描、核心测试、真实 GUI 冒烟和双次可复现构建。
- Release 至少包含 Windows x64 ZIP、独立 SPDX SBOM、`SHA256SUMS.txt` 和三项构建
  溯源证明。
- 解压 ZIP 后再次运行 `tools/verify-release.ps1` 所覆盖的结构检查；确认不含个人配置。
- 确认包内 AutoHotkey 许可证、对应源码归档、工具链锁和第三方许可证都能打开。
- 从干净目录按 README 完成一次安装、添加目标、退出、重载和卸载流程。

## 发布后

- 从未登录浏览器检查 README、相对链接、Issue 模板、安全私报入口和 Release 下载。
- 下载 GitHub 实际托管的产物并核对 SHA-256 与构建输出一致。
- 验证构建溯源证明显示正确仓库、工作流、提交和标签。
- 记录首发后发现的问题；需要改变用户行为或配置格式时更新变更日志和迁移说明。
