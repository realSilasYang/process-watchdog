# 发布流程

**简体中文** | [English](en/release-process.md)

本机发布前统一运行 `powershell -ExecutionPolicy Bypass -File
tools\invoke-local-release-preflight.ps1`。该入口会按官方摘要准备便携 PowerShell 7、
刷新本次上游构建工具，并一次完成下列必需测试、300 秒 Windows／GUI 长测和双宿主
可复现构建；任何一步失败都会停止，修复后从同一入口重跑。

1. 按[更新日志模板](changelog-template.md)整理面向用户的版本条目，并创建对应的
   `docs/release-notes/v<版本>.md` 发行说明，再同步更新 `VERSION`、`CHANGELOG.md`
   和英文更新日志。编译文件版本由构建脚本从 `VERSION`
   注入。文档标题必须保留 `📋`，版本标题必须使用
   `## 🎉 版本 [X.Y.Z] - YYYY-MM-DD`。`⚠️ 重要说明`不是固定模块，默认不生成；
   只有数据或配置不兼容、数据丢失风险、破坏性的最低环境／权限／默认行为变化，或
   用户必须执行迁移、备份、替换等升级操作时才加入，并写清受影响对象、风险和操作。
   “保持兼容”“可直接升级”、下载建议、功能简介和一般使用提示不得放入该章节；没有
   合格事项时必须连标题一起省略。每个正式版本必须保留
   `📦 发布物说明`，逐项写明三个准确文件名、版本定位、包含内容、AutoHotkey 要求
   和适用场景；该章节固定放在 Release 正文最后，方便用户阅读完版本变化后直接选择下载。
   CHANGELOG 和 Release Notes 都不得加入“✅ 验证范围”章节；测试数量、浸泡结果、
   构建哈希和未完成的人工矩阵只记录在验证证据与 Actions 日志中。
2. 确认仓库不是浅克隆并已取得全部分支和标签。运行 `tests/verify.ps1`；该入口
   会使用锁定版本的 Gitleaks 扫描完整历史，并拒绝曾被提交的个人运行配置、临时
   探针、凭据及当前发布文本中的本机路径。
3. 运行
   `tests/verify-windows-integration.ps1 -SoakSeconds 300`；发布前的完整核心、字体和 UI 场景压力测试
   不得缩短。
4. 发布负责人重新确认 PingFang、SF Pro Text 与 Apple SD Gothic Neo 的商业授权
   仍覆盖 `assets/fonts/metadata.json` 所列精确文件、Windows、公开仓库和 Release
   分发；未确认时不得触发正式发布。
5. 运行 `tests/reproducible-build.ps1`，保存脚本输出的最终 SHA-256；主分支非文档 CI、
   发行工程 Pull Request、演练和正式发布会分别以 PowerShell 7 与 Windows PowerShell 5.1 构建并比较。两次便携 ZIP、
   源码 ZIP、可选字体 ZIP 或独立 SBOM 哈希不同，或 `SHA256SUMS.txt` 不匹配时不得发布。
6. 普通 CI 使用仓库内经哈希固定的 `tools/ci-toolchain.resolved.json` 和缓存，先按
   路径分类：纯文档只运行不需要 LFS 的快速门禁；运行时变更增加真实 Windows／GUI；
   主分支非文档变更和发行工程 Pull Request 再增加可复现打包，避免上游变化和大型
   资源处理拖慢无关提交。发布演练与正式发布则重新查询 AutoHotkey 最新稳定版和
   Ahk2Exe 最新发布版，并冻结本次 `toolchain.resolved.json`。检查发行目录包含
   AutoHotkey 许可证、对应提交的完整源码归档和这份解析快照，且 SBOM 与实际归档
   哈希一致。
7. 在人工 GUI 矩阵中检查受影响的 Windows 与 DPI 组合；完成情况与未覆盖组合统一
   记录在 GUI 验证证据和手工回归矩阵中，不能用自动化结果代替，也不写入 CHANGELOG
   或 Release Notes。
8. 检查 README、兼容性、安装和故障排查文档与实际行为一致。CHANGELOG 每项应说明
   用户能够观察到的变化，不直接复制提交信息或内部类名。
9. 提交全部源码、测试和文档并推送发布分支。为该分支创建发行工程 Pull Request，
   等待包括 `verify` 在内的全部必需检查通过；不得绕过受保护规则直接推送 `main`。
   复核 PR 的提交与变更范围后使用 merge commit 合入 `main`，再确认远端 `main`
   正好包含该合并提交且可从 Git 重建。此阶段不要手工创建或推送版本标签。
10. 在 GitHub Actions 中从合并后的 `main` 人工运行 Release dry run。它以只读权限重新解析
    最新上游工具链，执行与正式发布相同的完整验证、GUI 冒烟和双次可复现构建，并
    保留完整 `dist`；它不会创建标签、草稿或 Release。演练失败时不得继续。
11. 演练通过后，从同一 `main` 提交人工运行 Release。不要预先推送版本标签；工作流
    会拒绝其他提交的标签或草稿，以及任何已公开版本。同一提交的草稿或孤立标签可
    安全续传，重复记录和不一致状态会明确失败。
12. 正式工作流再次动态解析上游工具链并执行全部门禁。通过后只为完整便携 ZIP、完整
    源码 ZIP 和可选字体 ZIP 生成溯源证明并上传到草稿；SBOM、`SHA256SUMS.txt` 和其余
    `dist` 只保存在完整 Actions 构建产物中；上传时必须显式包含隐藏目录。草稿正文、提交、附件白名单、大小和
    GitHub SHA-256 摘要与本地构建完全一致后才公开。公开后不仅再次审计远程标签和
    Release，还会从 GitHub 下载两个程序版本和可选字体包，重新核对摘要、解压 ZIP，
    并以包内正式工具链快照复用完整发行包校验；仓库的普通 CI 快照不会混入该步骤。

标签必须属于 `main` 历史，并由人工 Release 工作流在全部门禁通过后创建。推送代码、
推送标签、定时任务和普通 CI 都不会发布。不要改写已经发布的标签；
发布后发现需要修正的代码或文档时，应增加补丁版本。Release 正文使用对应的
`docs/release-notes/v<版本>.md`，并以 CHANGELOG 条目为事实源，同时列出附件用途、
运行要求和适用场景；测试与人工验收证据留在专门的验证记录中。
Release 只保留两个程序版本（完整便携 ZIP、完整源码 ZIP）和可选字体 ZIP。字体包提供
首选和回退界面字体，需安装到 Windows，不是程序运行必需。发布说明同时链接
[Everything 官方最新版](https://www.voidtools.com/downloads/)，说明它为程序搜索提供索引和后台服务，且
`Everything64.dll` 只是 IPC 客户端、不能替代 Everything 本体。SBOM、
`SHA256SUMS.txt` 及解压后的发行目录只保存在 Actions 完整构建产物中。
若公开后的最终审计失败，禁止删除或覆盖已公开版本；应保留现场、定位原因并发布新的
补丁版本。正式发布状态判断和两次审计都由 `tools/ReleaseEngineering.psm1` 的同一
合同执行，不在工作流 YAML 中维护另一套判断逻辑。

发布包不签名。若以后加入代码签名，应在确定性未签名构建之后执行，并分别保存
未签名构建哈希、签名产物哈希和签名证书信息。
