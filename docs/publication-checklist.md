# 正式发布清单

**简体中文** | [English](en/publication-checklist.md)

本清单区分“本地仓库已经可公开”和“托管平台已经正确配置”。后者需要仓库创建后
由维护者在 GitHub 完成，不能由本地测试结果替代。

## 创建仓库前

- `tests/verify.ps1` 在完整、非浅克隆中通过。
- `tests/verify-windows-integration.ps1 -SoakSeconds 300` 通过，核心测试、完整字体哈希、GDI 和 USER 增长均符合要求。
- 当前发行 EXE 与完成长时 GUI 压力测试的 EXE 哈希一致；若不一致，重新运行长测。
- `tests/reproducible-build.ps1` 连续两次产生相同独立 EXE、EXE ZIP、源码 ZIP 和
  SBOM 哈希。
- `git log --all --name-only` 不包含真实配置、维护会话或临时探针。
- `watchdog.ini` 和 `watchdog.maintenance.ini` 仍被忽略且哈希未改变。
- `VERSION` 与两份 CHANGELOG 完全一致，目标版本标签尚不存在。
- CHANGELOG 已按 `docs/changelog-template.md` 合并零散提交，并明确配置迁移、默认值、
  权限变化和用户必须执行的操作。
- `⚠️ 重要说明`仅在存在不兼容、数据风险、破坏性环境／权限／默认行为变化或强制升级
  操作时出现；兼容性未变化、可直接升级和下载建议不用于凑该章节，无事项时完全省略。
- CHANGELOG 和 Release 说明保留规定的 Emoji 标题；`📦 发布物说明`逐项列出三个
  准确文件名、版本定位、包含内容、AutoHotkey 要求和适用场景，并固定为 Release
  正文最后一个章节。
- CHANGELOG 和 Release Notes 均不包含“✅ 验证范围”章节；测试数量、浸泡结果、
  构建哈希及尚未完成的物理矩阵只保存在验证证据和 Actions 日志中。

## GitHub 仓库设置

1. 创建空仓库，不自动生成 README、许可证或 `.gitignore`，避免无关合并提交。
2. 推送 `main` 并确认 CI 全部通过；不要手动推送版本标签，之后从 Actions 人工运行
   Release 工作流。
3. 在“Settings → General”启用 Issues，按需关闭 Discussions 和 Wiki。
4. 在“Settings → Code security”启用 Dependabot alerts、Dependabot security updates、
   Secret scanning、Push protection 和 Private Vulnerability Reporting。
5. 为 `main` 建立规则集：禁止强制推送和删除，要求 Pull Request、讨论已解决、
   分支保持最新，并要求 CI 的 `fast` 检查通过；运行时与发行工程分层由工作流按路径
   自动追加。只有一名维护者时审批数设为零，
   避免作者无法批准自己的 PR；增加第二名维护者后再启用 CODEOWNERS 审批。
6. 保留 Actions 的默认最小权限；发布工作流只使用文件内显式声明的 `contents`、
   `id-token` 和 `attestations` 权限。
7. 检查 Actions 允许使用仓库中已经固定完整提交 SHA 的第三方 Action。
8. 在仓库 About 中填写简洁描述、Windows／AutoHotkey 主题和实际许可证。

## 正式 Release

- 先从 `main` 人工运行只读 Release dry run；确认它不创建标签或 Release，并保留完整
  `dist` Actions 产物。演练通过后才能从同一提交人工运行 Release。
- Release 工作流只能从 `main` 人工触发，并在全部门禁通过后创建 `v<VERSION>` 标签。
- 工作流解析出的 AutoHotkey 必须是最新稳定版，Ahk2Exe 必须是最新发布版；同一次
  发布的测试、两次构建和 SBOM 必须共用一份解析快照。
- Release 工作流重新执行全历史扫描、核心测试、真实 GUI 冒烟和双次可复现构建。
- Release 只包含独立 EXE、Windows x64 ZIP 和源码 ZIP；独立 SPDX SBOM、
  `SHA256SUMS.txt`、解压目录及其他构建输出只在 Actions 完整产物中保留。
- 附件上传期间 Release 保持草稿；工作流按三项白名单核对实际附件后才公开。
  若中断，只能续传同一提交的草稿，不能覆盖已发布版本。
- 公开后再次确认远程标签、提交、标题、正文和三个附件的 GitHub SHA-256，再由
  `tools/verify-downloaded-release.ps1` 下载实际托管的三个版本、解压两个 ZIP，并以
  包内正式工具链快照运行完整结构检查；确认不含个人配置。最终审计失败时保留已公开
  现场并改发补丁版本，不删除或覆盖。
- 确认包内 AutoHotkey 许可证、对应源码归档、工具链解析快照和第三方许可证都能打开。
- 发布负责人重新确认 PingFang、SF Pro Text 与 Apple SD Gothic Neo 的商业授权仍然
  有效，并覆盖本次文件版本、Windows 平台、GitHub 仓库及 Release 分发方式。
- 从干净目录按 README 完成一次安装、添加目标、退出、重载和卸载流程。

## 发布后

- 从未登录浏览器检查 README、相对链接、Issue 模板、安全私报入口和 Release 下载。
- 分别预览缺陷、功能和改进建议表单，确认字段、标签、支持链接和私密安全入口可用。
- 确认工作流中的下载后验收已经通过；需要独立复核时运行
  `tools/verify-downloaded-release.ps1 -Version <版本> -CommitSha <标签提交>`。
- 验证构建溯源证明显示正确仓库、工作流、提交和标签。
- 记录首发后发现的问题；需要改变用户行为或配置格式时更新变更日志和迁移说明。
