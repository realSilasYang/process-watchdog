# 界面图标来源

主列表管理员徽标不随项目复制第三方图片。运行时通过微软公开的
`SHGetStockIconInfo` 接口请求 `SIID_SHIELD`，从当前 Windows 的系统 Jumbo
图像列表取得原生 UAC 盾牌，再由 WIC 按当前 DPI 高质量缩小并叠加到应用图标
右下角。这样显示的是用户当前 Windows 自带的官方设计，也不会产生额外的图标
再分发许可。

- 微软接口文档：
  <https://learn.microsoft.com/windows/win32/api/shellapi/nf-shellapi-shgetstockiconinfo>
- 库存图标标识文档：
  <https://learn.microsoft.com/windows/win32/api/shellapi/ne-shellapi-shstockiconid>

随包提供的 Lucide 图标来源与许可证见 [`lucide/`](lucide/)。
