# UI font resources

This directory contains preferred and fallback fonts used when the matching UI
font is not installed. The assistant loads them with
`AddFontResourceExW` and `FR_PRIVATE`; they are visible only to the current
process and never installed into Windows or written to system font settings.

- `PingFang.ttc` is the commercially licensed original PingFang 19.0d5e3
  collection. Its 36 faces cover Simplified Chinese, Hong Kong Traditional
  Chinese, and Taiwan Traditional Chinese at six weights each.
- `SF-Pro-Text-Regular.otf` and `SF-Pro-Text-Bold.otf` are the commercially
  licensed SF Pro Text 22.0d4e4 regular and bold faces for English, Vietnamese,
  Spanish, French, Portuguese, Russian, German, and Italian. The Text family is
  optimized for the small UI sizes used by the assistant.
- `AppleSDGothicNeo-Regular.ttf` is the commercially licensed Apple SD Gothic
  Neo 1.0 regular face for Korean. The source bold file uses a separate family
  name and cannot act as the bold face of the selected regular family, so that
  ineffective asset is not packaged.
- `HaranoAjiGothic-Regular.otf` was selected from the user-designated Apple-font
  directory, but is an independent open-source Harano Aji Gothic 20250811 font,
  not an Apple-proprietary font. Its OFL 1.1 license permits packaging, and the
  Japanese interface privately loads it when the family is not installed.
- `NotoSans-Variable.ttf` is the byte-identical
  `NotoSans[wdth,wght].ttf` file from the Google `NoTofu` collection, renamed
  only so the runtime can validate its asset name safely. Noto Sans 2.015
  covers English, Vietnamese, Spanish, French, Portuguese, Russian, German,
  and Italian and provides variable weight and width axes.
- `NotoSansCJK.ttc` is the original Noto Sans CJK 2.004 collection from the
  same `NoTofu` source. Its 45 faces provide Simplified Chinese, Hong Kong and
  Taiwan Traditional Chinese, Japanese, and Korean families at multiple
  weights. No face extraction, subsetting, or font-family renaming is applied.

Harano Aji Gothic and both Noto resources use the SIL Open Font License 1.1;
`OFL-1.1.txt` contains the complete license. The other four files are provided
under the project owner's commercial redistribution authorization, whose public
boundary is documented in `COMMERCIAL-LICENSE-NOTICE.en.md`. `metadata.json`
records the source collection, original names, families, versions, and SHA-256
values for every resource. Fonts ship as external full-package assets rather
than being embedded in the EXE.
