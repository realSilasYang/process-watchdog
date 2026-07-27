# 界面字体资源

本目录保存小助手在目标语言首选字体未安装时所需的首选和回退字体。字体通过
`AddFontResourceExW` 以 `FR_PRIVATE` 方式加载，只在当前小助手进程内可见；
不会安装到 Windows，也不会修改系统字体配置。

- `PingFang.ttc`：商业授权的 PingFang 19.0d5e3 原始集合。36 个字体面覆盖
  简体中文、香港繁体和台湾繁体及各自的 Regular、Medium、Semibold、Light、
  Thin 与 Ultralight 字重。
- `SF-Pro-Text-Regular.otf` 与 `SF-Pro-Text-Bold.otf`：商业授权的 SF Pro Text
  22.0d4e4 常规和粗体，供英语、越南语、西班牙语、法语、葡萄牙语、俄语、德语
  和意大利语界面使用。Text 版本针对当前界面的小字号正文优化。
- `AppleSDGothicNeo-Regular.ttf`：商业授权的 Apple SD Gothic Neo 1.0 常规字体，
  供韩文界面使用。源目录中的粗体采用另一个独立家族名，不能作为当前常规家族的
  自动粗体，因此没有把无效文件加入发行包。
- `HaranoAjiGothic-Regular.otf`：从用户指定的 Apple 字体目录选取，但它本身是
  独立的开源 Harano Aji Gothic 20250811，而不是 Apple 专有字体。该文件采用
  OFL 1.1，可以随包分发；日文界面会在系统未安装该家族时优先私有加载它。
- `NotoSans-Variable.ttf`：来自 Google `NoTofu` 字体集中的
  `NotoSans[wdth,wght].ttf` 原始文件，版本为 Noto Sans 2.015。它覆盖英语、
  越南语、西班牙语、法语、葡萄牙语、俄语、德语和意大利语，并提供字重与字宽
  可变轴。发行文件只采用便于脚本安全解析的名称，二进制内容没有修改。
- `NotoSansCJK.ttc`：来自同一 `NoTofu` 字体集的 Noto Sans CJK 2.004 原始
  集合，包含 45 个字体面，分别提供简体中文、香港繁体、台湾繁体、日文和韩文
  家族及多个字重。文件未做抽取、子集化或重命名字体家族。

Harano Aji Gothic 与两个 Noto 文件采用 SIL Open Font License 1.1，完整许可证见
`OFL-1.1.txt`。其余四个文件依据项目所有者持有的商业分发授权提供，边界见
`COMMERCIAL-LICENSE-NOTICE.md`。全部资源的来源集合、原始文件名、家族、版本和
SHA-256 均记录在 `metadata.json`。字体作为外置资源进入完整发行包，不嵌入单个
EXE。
