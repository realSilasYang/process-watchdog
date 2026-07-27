# 发布流程

**简体中文** | [English](en/release-process.md)

1. 按[更新日志模板](changelog-template.md)整理面向用户的版本条目，并创建对应的
   `docs/release-notes/v<版本>.md` 发行说明，再同步更新 `VERSION`、`CHANGELOG.md`
   和英文更新日志。编译文件版本由构建脚本从 `VERSION`
   注入。版本标题必须使用
   `## [X.Y.Z] - YYYY-MM-DD`；配置迁移、默认值、权限或用户操作变化必须置于
   “重要说明”，没有内容的分类直接删除。
2. 确认仓库不是浅克隆并已取得全部分支和标签。运行 `tests/verify.ps1`；该入口
   会使用锁定版本的 Gitleaks 扫描完整历史，并拒绝曾被提交的个人运行配置、临时
   探针、凭据及当前发布文本中的本机路径。
3. 运行
   `tests/run-gui-tests.ps1 -SoakSeconds 300`；发布前的完整 UI 场景压力测试
   不得缩短。
4. 发布负责人重新确认 PingFang、SF Pro Text 与 Apple SD Gothic Neo 的商业授权
   仍覆盖 `assets/fonts/metadata.json` 所列精确文件、Windows、公开仓库和 Release
   分发；未确认时不得触发正式发布。
5. 运行 `tests/reproducible-build.ps1`，保存脚本输出的最终 SHA-256；两次独立 EXE、
   EXE ZIP、源码 ZIP 或独立 SBOM 构建哈希不同，或 `SHA256SUMS.txt` 不匹配时不得发布。
6. 本地预检可复用已解析的构建工具；正式发布工作流会重新查询 AutoHotkey 最新
   稳定版和 Ahk2Exe 最新发布版，并冻结一次性的 `toolchain.resolved.json`。检查发行
   目录包含 AutoHotkey 许可证、对应提交的完整源码归档和这份解析快照，且 SBOM
   与实际归档哈希一致。
7. 在人工 GUI 矩阵中检查受影响的 Windows 与 DPI 组合；未完成的物理组合必须在
   Release 说明中列出，不能用自动化结果代替。
8. 检查 README、兼容性、安装和故障排查文档与实际行为一致。CHANGELOG 每项应说明
   用户能够观察到的变化，不直接复制提交信息或内部类名。
9. 提交全部源码、测试和文档，确保 `main` 工作区可从 Git 重建且 CI 已通过。
10. 在 GitHub Actions 中从 `main` 人工运行 Release 工作流。不要预先推送版本标签；
   工作流会确认 `VERSION` 合法，并且只接受人工触发。首次运行要求远程同名标签
   不存在；如果同一提交的草稿发布曾中断，可以重跑并续传该草稿。
11. 工作流动态解析上游工具链后重新执行完整验证、短时 GUI 压力测试和双次可复现
    构建；全部通过才为独立 EXE、完整便携 ZIP 和完整源码 ZIP 生成发行物及溯源证明。
    SBOM 与 `SHA256SUMS.txt` 作为验证附件保留，把完整 `dist` 保存为 Actions 产物。所有附件先上传到草稿并按名称完整核对，
    核对通过后才把 `v<版本>` Release 一次性公开。

标签必须属于 `main` 历史，并由人工 Release 工作流在全部门禁通过后创建。推送代码、
推送标签、定时任务和普通 CI 都不会发布。不要改写已经发布的标签；
发布后发现需要修正的代码或文档时，应增加补丁版本。Release 正文使用对应的
`docs/release-notes/v<版本>.md`，并以 CHANGELOG 条目为事实源，同时列出附件用途、
校验方式和尚未完成的物理 GUI 验证。
Release 长期保留三种用户版本：独立 EXE、完整便携 ZIP 和完整源码 ZIP。SBOM、
`SHA256SUMS.txt` 及解压后的发行目录属于验证或构建附件，不计入用户版本种类。

发布包不签名。若以后加入代码签名，应在确定性未签名构建之后执行，并分别保存
未签名构建哈希、签名产物哈希和签名证书信息。
