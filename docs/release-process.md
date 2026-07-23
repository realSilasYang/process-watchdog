# 发布流程

1. 更新 `VERSION`、主脚本 Ahk2Exe 文件版本和 `CHANGELOG.md`。
2. 运行 `tests/verify.ps1`、`tests/run-gui-tests.ps1` 和
   `tests/reproducible-build.ps1`。
3. 在人工 GUI 矩阵中检查受影响的 Windows 与 DPI 组合。
4. 提交全部源码、锁定文件、测试和文档，确保工作区可从 Git 重建。
5. 创建与 `VERSION` 完全一致的标签，例如 `v0.1.0`。
6. Release 工作流重新验证、构建并发布 ZIP 与 `SHA256SUMS.txt`。

发布包不签名。若以后加入代码签名，应在确定性未签名构建之后执行，并分别保存
未签名构建哈希、签名产物哈希和签名证书信息。
