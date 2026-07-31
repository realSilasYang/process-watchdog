<div align="center">
  <img src="../assets/app/watchdog-logo.png" width="112" alt="Biểu trưng Process Watchdog Assistant">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <strong>Tiếng Việt</strong> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Trợ lý giám sát tiến trình</h1>

  <p><strong>Giữ các ứng dụng và tác vụ tự động thiết yếu luôn hoạt động ổn định</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="Phiên bản mới nhất"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="Lượt tải GitHub"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="Trạng thái CI"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="Giấy phép"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Hỗ trợ Windows 10 và Windows 11">
  </p>

  <p>
    <a href="#tổng-quan-giao-diện">Giao diện</a> ·
    <a href="#hướng-dẫn-sử-dụng">Hướng dẫn</a> ·
    <a href="#3-trạng-thái-và-khôi-phục">Trạng thái</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">Bản phát hành</a> ·
    <a href="./CHANGELOG.en.md">Nhật ký thay đổi</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">Báo lỗi</a> ·
    <a href="#hướng-dẫn-dành-cho-nhà-phát-triển">Dành cho nhà phát triển</a>
  </p>
</div>

Trợ lý giám sát tiến trình dành cho các ứng dụng, tập lệnh và lối tắt cần hoạt động lâu dài trong phiên máy tính Windows hiện tại. Khi đích thoát ngoài ý muốn, trợ lý sẽ tự động khôi phục một cách thận trọng, đồng thời phân biệt giữa “đã xác nhận dừng” và “tạm thời chưa thể xác định” để tránh khởi chạy nhầm hoặc tạo phiên bản trùng lặp. Mọi quyết định, cài đặt và nhật ký đều được giữ trên máy. Dự án được xây dựng bằng AutoHotkey v2 x64 và hỗ trợ Windows 10, Windows 11.

Trợ lý không chỉ dựa vào tên tiến trình. Nó kết hợp đường dẫn đầy đủ, danh tính tạo tiến trình, đích thật của lối tắt và bằng chứng dòng lệnh. Nếu bằng chứng chưa đủ, trợ lý sẽ chờ lần kiểm tra tiếp theo thay vì coi trạng thái chưa rõ là đã dừng.

Dự án có giao diện sáng và tối, khôi phục tự động, bảo vệ khi cập nhật phần mềm, nhật ký chạy, hoàn tác và làm lại, tên và biểu tượng hiển thị tùy chỉnh, cùng gói Windows x64 có SPDX SBOM, tổng kiểm SHA-256 và thông tin nguồn gốc bản dựng.

# Tổng quan giao diện

<p align="center">
  <img src="images/process-watchdog-overview.png" alt="Cửa sổ chính của Process Watchdog Assistant" width="100%">
</p>

Cửa sổ chính hiển thị thứ tự đối tượng giám sát, biểu tượng ứng dụng, tên, yêu cầu đặc quyền và trạng thái hiện tại. Thanh lệnh có các thao tác Thêm, Xóa, Tạm dừng, Cài đặt, Thông tin trợ giúp và Ủng hộ; từ Thông tin trợ giúp có thể mở hướng dẫn hoặc nhật ký chạy. Thanh dưới cùng tổng hợp số đối tượng đang chạy, đang khôi phục, đang cập nhật, tạm dừng và thất bại; nhật ký giải thích bằng chứng đứng sau từng trạng thái bất thường.

## Điểm nổi bật

- Giám sát đích EXE, AHK, Python, JavaScript, PowerShell, BAT, CMD và LNK.
- Dùng ba kết quả `Running`, `Stopped`, `Unknown`; trạng thái chưa rõ không bao giờ tự động kích hoạt khởi động lại mù quáng.
- Mỗi đích có bộ điều khiển, thế hệ và mã tác vụ riêng; lệnh gọi lại cũ bị vô hiệu ngay sau khi tạm dừng, xóa hoặc đổi đường dẫn.
- Có thể yêu cầu quyền quản trị. Trợ lý báo khi tiến trình đang chạy không đủ quyền và sẽ nâng quyền cho lần khởi chạy được giám sát tiếp theo.
- Bảo vệ khi cập nhật mặc định tắt. Khi bật, trợ lý kết hợp tiến trình cập nhật, quan hệ cha con, hoạt động thư mục cài đặt và độ ổn định của tệp trước khi tạm dừng hoặc tiếp tục giám sát.
- Thay thế cấu hình theo giao dịch nguyên tử. Bản ghi không phân tích được sẽ chuyển vào `[Recovery]` thay vì bị bỏ mất.
- Tìm ứng dụng chỉ qua dịch vụ Everything, không quét toàn bộ ổ đĩa bằng cơ chế tích hợp và không giới hạn số kết quả. Tập kết quả lớn được thêm theo từng đợt ngắn để việc lấy biểu tượng không làm treo giao diện.
- Hỗ trợ tiếng Trung giản thể, tiếng Trung phồn thể Hồng Kông, tiếng Trung phồn thể Đài Loan, tiếng Anh, tiếng Nhật, tiếng Việt, tiếng Hàn, tiếng Tây Ban Nha, tiếng Pháp, tiếng Bồ Đào Nha Brazil, tiếng Nga, tiếng Đức và tiếng Ý. Mặc định giao diện theo ngôn ngữ Windows, ngôn ngữ chưa hỗ trợ sẽ dùng tiếng Anh; người dùng cũng có thể chọn trong mục Chung. Thay đổi ngôn ngữ và phông nội dung có hiệu lực ngay trong tiến trình hiện tại, không dừng hay khởi tạo lại tác vụ giám sát.
- Ở chế độ “Theo mặc định của ngôn ngữ”, trợ lý ưu tiên PingFang, SF Pro Text, Harano Aji Gothic hoặc Apple SD Gothic Neo. Nếu máy chưa cài, tài nguyên đi kèm có giấy phép thương mại hoặc OFL được nạp riêng cho tiến trình, sau đó mới lui về họ Noto tương ứng. Phông nội dung áp dụng cho phần thân, ô nhập, danh sách và thông tin Giới thiệu; nút, thẻ Cài đặt và thanh trạng thái cửa sổ chính luôn dùng phông UI Windows in đậm tương ứng với ngôn ngữ hiện tại.
- Giao diện sáng/tối hỗ trợ thu nhỏ cửa sổ con độc lập, dựng lại biểu tượng theo DPI, nút bo góc và biểu tượng tùy chỉnh.
- Gói chẩn đoán chỉ được tạo trên máy và không tự tải lên; hiện vật phát hành chính thức có thể được xác minh độc lập.

## Phạm vi sử dụng

Phù hợp với ứng dụng, tập lệnh và lối tắt thông thường cần tiếp tục chạy trong phiên máy tính Windows hiện tại và tự khôi phục sau khi thoát ngoài ý muốn. Các đối tượng sau nằm ngoài phạm vi:

- Dịch vụ Windows, trình điều khiển, thành phần nhân hoặc dịch vụ chạy qua nhiều phiên người dùng.
- Windows 7, Windows 32-bit và nền tảng không phải Windows.
- Hệ thống thời gian thực cứng, cụm khả dụng cao hoặc điều phối tiến trình cần ranh giới cách ly bảo mật.
- Chính sách cực đoan coi mọi trạng thái tiến trình chưa rõ là đã dừng.

Đã ghi nhận một lượt tự động hóa GUI đầy đủ trên Windows 11 với DPI thực 200%, đồng thời phép tính dựng hình ở 100% và 300% được bao phủ bằng kiểm thử hồi quy. Việc kiểm tra trực quan thủ công ở mọi tỷ lệ, chuyển DPI liên tục giữa các màn hình và chế độ tương phản cao vẫn chưa được xác minh, không được suy ra chỉ từ mã nguồn. Xem [hồ sơ xác minh GUI](../tests/gui/VALIDATION-EVIDENCE.en.md) và [Khả năng tương thích và giới hạn đã biết](en/compatibility.md).

---

**[Hướng dẫn sử dụng](#hướng-dẫn-sử-dụng)**<br>
[Cài đặt](#1-cài-đặt-và-lần-chạy-đầu) · [Quản lý mục](#2-thêm-và-quản-lý-mục) · [Trạng thái](#3-trạng-thái-và-khôi-phục) · [Bảo vệ cập nhật](#4-bảo-vệ-khi-cập-nhật) · [Cài đặt](#5-cài-đặt) · [Nhật ký](#6-nhật-ký-chẩn-đoán-và-quyền-riêng-tư)

**[Hướng dẫn dành cho nhà phát triển](#hướng-dẫn-dành-cho-nhà-phát-triển)**<br>
[Thư mục](#1-thư-mục-và-trách-nhiệm) · [Ranh giới đúng đắn](#2-ranh-giới-đúng-đắn) · [Xác minh](#3-lệnh-xác-minh) · [Phát hành](#4-phát-hành-và-đóng-góp)

# Ủng hộ dự án

Nếu trợ lý đã giúp bạn tiết kiệm thời gian tìm lỗi hoặc khôi phục ứng dụng, hãy ủng hộ tác giả qua một trong hai mã QR dưới đây. Vui lòng chọn cách ủng hộ:

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="Mã QR ủng hộ qua WeChat Pay">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Mã QR ủng hộ qua Alipay">
</p>

# Hướng dẫn sử dụng

## 1. Cài đặt và lần chạy đầu

1. Trong [Releases](https://github.com/realSilasYang/process-watchdog/releases), hãy chọn ZIP di động đầy đủ hoặc ZIP mã nguồn đầy đủ. Gói phông chữ tùy chọn không phải là phiên bản chương trình thứ ba.
2. ZIP di động chạy sau khi giải nén đầy đủ và không cần cài AutoHotkey riêng; ZIP mã nguồn cần AutoHotkey v2 x64. Phông chữ phải được cài vào Windows nhưng không bắt buộc để chạy chương trình; tìm kiếm ứng dụng cũng cần [Everything chính thức mới nhất](https://www.voidtools.com/downloads/).
3. Chạy `进程守护小助手.exe`. Ứng dụng yêu cầu quyền quản trị, sau đó hiển thị cửa sổ chính hoặc nằm trong khay hệ thống tùy cài đặt.
4. Chọn Thêm để chọn đích, hoặc kéo tệp được hỗ trợ vào cửa sổ chính.
5. Mở Nhật ký để xem bằng chứng danh tính, kiểm tra trạng thái, lần thử khôi phục và tín hiệu cập nhật thực tế.

Để chạy từ mã nguồn, hãy cài AutoHotkey v2 x64 rồi chạy `进程守护小助手.ahk`. Nếu sao chép kho mã bằng Git, bạn cũng phải cài Git LFS và chạy `git lfs pull` để nhận tệp phông chữ đầy đủ thay vì tệp con trỏ LFS. Gói ZIP mã nguồn đính kèm Release đã chứa các tài nguyên này nên không cần Git LFS. Bản phát hành chính thức đã nhúng môi trường AutoHotkey vượt qua toàn bộ kiểm thử, nên người dùng thông thường không cần cài AutoHotkey riêng.

### Phiên bản và hình thức chạy

| Thành phần | Bản EXE | Bản mã nguồn |
| --- | --- | --- |
| Trợ lý | Đọc phiên bản tệp EXE; khi cập nhật sẽ thay toàn bộ gói phát hành | Đọc `VERSION` cạnh tệp vào; cập nhật bằng Git fast-forward an toàn hoặc gói mã nguồn |
| AutoHotkey | Được nhúng và cập nhật cùng gói trợ lý mới | Dùng trình thông dịch trên máy; cập nhật trợ lý không nâng cấp AutoHotkey |
| Ahk2Exe | Chỉ dùng trên máy phát hành để tạo EXE, không cài trên máy người dùng | Không cần |

“Trợ lý đã là phiên bản mới nhất” không đồng nghĩa với “AutoHotkey trên máy là phiên bản mới nhất”. Khi bắt đầu mỗi bản phát hành chính thức, quy trình chọn bản AutoHotkey ổn định mới nhất và bản Ahk2Exe đã phát hành mới nhất, cố định chúng rồi chạy toàn bộ kiểm thử trước khi nhúng AutoHotkey. Cài đặt trợ lý → Giới thiệu hiển thị phiên bản trợ lý, hình thức EXE/mã nguồn và phiên bản AutoHotkey thực tế; tại đây cũng có thể kiểm tra cập nhật thủ công. Xem [Phiên bản, hình thức chạy và trách nhiệm cập nhật](en/versioning.md).

Đóng cửa sổ chính chỉ ẩn nó vào khay hệ thống; giám sát vẫn tiếp tục. Dùng Thoát trong trình đơn khay để dừng hoàn toàn. Xem [Cài đặt, nâng cấp và gỡ bỏ](en/installation.md) về lối tắt, tác vụ khởi động và nâng cấp.

## 2. Thêm và quản lý mục

| Nút | Chức năng |
| --- | --- |
| Thêm | Chọn đích, tìm ứng dụng đã cài hoặc nhập thư mục; mặc định bao gồm thư mục con |
| Xóa | Xóa các mục đã chọn; hỗ trợ chọn nhiều và hoàn tác |
| Tạm dừng / Tiếp tục | Chỉ đổi trạng thái giám sát tự động, không đóng đích đang chạy; lựa chọn hỗn hợp được đảo từng mục |
| Cài đặt | Cấu hình Chung, Giám sát & khởi chạy, Chính sách dừng, Nhật ký và Giới thiệu |
| Thông tin trợ giúp | Chọn hướng dẫn tích hợp, nhật ký chạy hoặc trang phản hồi GitHub |
| Ủng hộ | Hiện mã QR WeChat Pay và Alipay để hỗ trợ bảo trì |

Mỗi mục có thể đặt tệp vào để khởi chạy, thư mục làm việc, đối số và yêu cầu quyền quản trị. LNK vẫn là tệp khởi chạy, còn đường dẫn chương trình thật được lưu riêng để nhận diện tiến trình; vì vậy không cần thay lối tắt gián tiếp do trình cài đặt tạo bằng một EXE nội bộ dễ thay đổi.

Nhấp phải một mục để mở vị trí tệp, kết thúc chạy đích, sửa đường dẫn, cấu hình nhận diện tiến trình và thiết lập khởi chạy; thay đổi yêu cầu quản trị; cấu hình bảo vệ cập nhật; hoặc tùy chỉnh tên và biểu tượng chỉ dùng trong cửa sổ chính. Kết thúc chạy cũng tạm dừng giám sát để đích không tự khởi động lại. Tùy chỉnh hiển thị không ảnh hưởng đến danh tính đích, cách khởi chạy hay bảo vệ cập nhật. Nếu hiển thị đang là mặc định, thao tác khôi phục mặc định sẽ bị vô hiệu.

Chỉ mục BAT và CMD mới hiện thêm lệnh Xem nhật ký đầu ra của tập lệnh; các loại đích khác không hiện lệnh này. Tệp nhật ký riêng chỉ được tạo khi trợ lý thực sự khởi chạy mục đó và thu cả đầu ra chuẩn lẫn lỗi chuẩn. Một tiến trình tập lệnh đã chạy sẵn sẽ không tự động có tệp này.

Kéo hàng để đổi thứ tự và lưu thứ tự đó. Dùng `Ctrl+Z`, `Ctrl+Y` hoặc `Ctrl+Shift+Z` để hoàn tác hay làm lại thao tác thêm, xóa, sắp xếp và thay đổi cấu hình. Số thứ tự bên trái luôn được tạo lại theo thứ tự hiển thị và không tham gia nhận diện, khởi chạy hay lưu cấu hình. Xem [Các tình huống thường gặp](en/quick-start.md).

## 3. Trạng thái và khôi phục

Trạng thái trong danh sách mô tả bằng chứng hiện có và bước tiếp theo; không nên chỉ nhìn màu biểu tượng.

| Trạng thái | Ý nghĩa |
| --- | --- |
| Đang chạy | Tìm thấy phiên bản đang chạy khớp danh tính đích |
| Đang chạy (không khớp quyền) | Tiến trình tồn tại nhưng không đáp ứng yêu cầu quản trị đã đặt |
| Đang chờ trạng thái / Có thể đã dừng | Bằng chứng chưa đủ hoặc vừa thấy tiến trình thoát; trợ lý đang kiểm tra lại và không khởi chạy trùng ngay |
| Đang khởi chạy / Đếm ngược thử lại | Đã xác nhận cần khôi phục và đang chờ lần thử tiếp theo theo chuỗi độ trễ |
| Đang cập nhật / Xác nhận độ ổn định của tệp | Bảo vệ cập nhật tạm dừng tự động khởi chạy cho đến khi hoạt động kết thúc và tệp ổn định |
| Đã tạm dừng | Tạm dừng kiểm tra và khôi phục tự động nhưng không đóng tiến trình đích |
| Đã dừng / Khởi chạy thất bại / Hết thời gian chờ | Khôi phục chưa thành công hoặc cần xác nhận; xem nhật ký để biết bằng chứng và nguyên nhân |

Chuỗi độ trễ thử lại mặc định là 1, 10 và 60 giây. Sau chuỗi nhanh, độ trễ cuối được dùng lại để tránh vòng lặp khởi chạy liên tục. Xóa, tạm dừng, đổi đường dẫn hoặc hoàn tác sẽ vô hiệu tác vụ đã lên lịch và kết quả bất đồng bộ cũ.

## 4. Bảo vệ khi cập nhật

Bảo vệ khi cập nhật mặc định tắt và phải được bật riêng cho từng mục:

1. Nhấp phải đích và mở Bảo vệ khi cập nhật.
2. Bật tự động nhận biết cập nhật và bảo vệ quá trình khởi chạy.
3. Kiểm tra phạm vi cài đặt, cửa sổ phát hiện thoát, thời gian chờ ổn định tệp và thời gian chờ cập nhật tối đa.
4. Lưu rồi để ứng dụng thực hiện một lần cập nhật thật theo cách bình thường. Trợ lý kết hợp tiến trình cập nhật, quan hệ cha con, hoạt động thư mục, thông báo tệp và đặc điểm trình cập nhật đã học để quyết định bắt đầu bảo vệ.

Sau khi xác nhận cập nhật, tự động khởi chạy được tạm giữ. Giám sát chỉ tiếp tục khi hoạt động đã kết thúc và tệp đích ổn định. Nếu phát hiện hết thời gian hoặc sai thực tế, dùng Kết thúc chờ cập nhật và tiếp tục giám sát. Trợ lý vẫn kiểm tra tệp vào có an toàn trước khi khôi phục.

Đây không phải trình cài đặt đa năng hay công cụ quản lý dịch vụ Windows. Với ứng dụng di động, trình cập nhật nằm ngoài thư mục cài đặt hoặc trình khởi chạy đặc biệt, hãy xem nhật ký trước khi chỉnh phạm vi và quy tắc.

## 5. Cài đặt

| Nhóm | Tùy chọn |
| --- | --- |
| Chung | Lối tắt Màn hình nền và menu Bắt đầu, tác vụ tự khởi động, hai hành vi khi khởi động, ngôn ngữ, phông nội dung và chủ đề |
| Giám sát & khởi chạy | Khoảng kiểm tra tiến trình, chuỗi độ trễ tự khởi động lại sau sự cố và việc bao gồm thư mục con khi nhập |
| Chính sách dừng | Thời gian chờ đóng ứng dụng GUI/CLI và quyền buộc kết thúc sau khi hết thời gian |
| Nhật ký | Xóa khi khởi động, giới hạn mục hiển thị, số ngày giữ nhật ký hàng loạt và đường dẫn lưu |
| Giới thiệu | Phiên bản ứng dụng/môi trường, kiểm tra cập nhật ngay và liên kết dự án nguồn mở |

Cửa sổ cài đặt kiểm tra phạm vi số. Chú thích trong `watchdog.ini` nằm bên cạnh đúng phần và mục tương ứng; nên dùng giao diện để tránh làm hỏng trường đã mã hóa. Xem [Cấu hình, sao lưu và khôi phục](en/configuration.md).

## 6. Nhật ký, chẩn đoán và quyền riêng tư

Nhật ký chạy cho phép chọn và sao chép văn bản, phóng to và đổi kích thước. Thanh cuộn chỉ hiện khi cần và nội dung nhật ký không thể sửa.

Với lỗi khó xác định, có thể xuất gói chẩn đoán cục bộ từ cửa sổ nhật ký. Gói này có thông tin ứng dụng, Windows, AutoHotkey, DPI, handle tài nguyên, giai đoạn giám sát, cảnh báo cấu hình và tóm tắt nhật ký hiện tại, nhưng không tự tải lên.

Cấu hình cá nhân nằm trong `watchdog.ini` ở thư mục chạy thực tế; phiên cập nhật chưa hoàn tất nằm trong `watchdog.maintenance.ini` cùng nơi. Bản di động và mã nguồn dùng thư mục tệp vào của chúng. Cả hai tệp bị Git bỏ qua và không có trong bản phát hành.

EXE di động và tệp vào mã nguồn chỉ dùng chung trạng thái khi ở cùng thư mục; EXE độc lập không dùng cấu hình cạnh tệp khởi động đã tải xuống. Khóa toàn máy ngăn nhiều hình thức chạy cùng lúc; lối tắt và tác vụ theo lịch trỏ tới hình thức chạy thực tế được tích hợp gần nhất. Xem [Cấu hình, sao lưu và khôi phục](en/configuration.md) và [Cài đặt, nâng cấp và gỡ bỏ](en/installation.md).

Nhật ký và gói chẩn đoán có thể chứa đường dẫn, đối số hoặc biến môi trường. Hãy kiểm tra và che thông tin nhạy cảm trước khi đăng công khai. Dùng [biểu mẫu Issue có cấu trúc](https://github.com/realSilasYang/process-watchdog/issues/new/choose) cho báo cáo thông thường và kênh báo cáo riêng tư cho lỗ hổng chưa sửa. Xem [Chẩn đoán cục bộ](en/diagnostics.md), [Khắc phục sự cố](en/troubleshooting.md) và [Hỗ trợ](../.github/SUPPORT.en.md).

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# Hướng dẫn dành cho nhà phát triển

## 1. Thư mục và trách nhiệm

```text
process-watchdog/
├─ .github/                 biểu mẫu Issue, quy trình và mẫu cộng tác
├─ app/                     trạng thái ứng dụng, nối giao diện và các cửa sổ
├─ assets/                  biểu tượng, ảnh ủng hộ và phông nạp riêng
├─ config/                  cấu hình mẫu hiện tại có chú thích tại chỗ
├─ docs/                    tài liệu người dùng, kiến trúc, đa ngôn ngữ, hình ảnh và quản trị
├─ src/                     cấu hình, lõi, chẩn đoán, thực thi, kiểm tra, bảo vệ cập nhật, nền tảng, UI và tự cập nhật
├─ runtime/                 trình hỗ trợ cập nhật nền dùng chung cho EXE và mã nguồn
├─ tests/                   kiểm thử lõi, GUI, phát hành và kho mã
├─ third_party/             DLL, giấy phép và danh mục phụ thuộc đã khóa
├─ tools/                   bản dựng, SBOM, xác minh phát hành và chuẩn bị chuỗi công cụ
└─ 进程守护小助手.ahk      điểm ghép thành phần và tệp khởi động
```

Tập lệnh gốc chỉ nạp mô-đun, nối phụ thuộc và khởi động ứng dụng. `src` không đọc các biến toàn cục gốc `App`, `Main` hoặc `GuiModules`; `app` nối năng lực lõi thuần với cửa sổ, nhật ký và thao tác hệ thống. Xem [Kiến trúc và ranh giới đúng đắn](en/architecture.md).

## 2. Ranh giới đúng đắn

- Danh tính đích, tệp khởi chạy và tùy chỉnh hiển thị độc lập; cài đặt hiển thị không được thay đổi quyết định giám sát.
- `Running`, `Stopped`, `Unknown` là kết quả bằng chứng bên ngoài; chỉ trạng thái dừng đã xác nhận mới được vào quy trình khôi phục.
- Mọi bộ hẹn giờ, lệnh gọi lại, trình theo dõi tệp, tiến trình làm việc, cửa sổ và tài nguyên gốc đều phải có đường dọn dẹp lặp lại an toàn.
- Ảnh chụp cấu hình, đối tượng giám sát và cài đặt bảo vệ cập nhật được xác nhận trong cùng một giao dịch; kiểm thử không được đọc hay ghi đè `watchdog.ini` cá nhân.
- Không đưa lại cách cuộn mượt bằng ảnh chụp GDI đã bị loại bỏ; ListView và nhật ký giữ cuộn gốc.
- Tuyên bố về DPI, biểu tượng, chế độ tối, phân cấp cửa sổ và khả năng tiếp cận phải có bằng chứng trên Windows và tỷ lệ thật; tự động hóa không thay thế ma trận màn hình vật lý.

## 3. Lệnh xác minh

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-windows-integration.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

`verify.ps1` kiểm tra hàm băm phụ thuộc, phân tích AHK, ràng buộc kiến trúc, kiểm thử lõi, ranh giới kho mã, rò rỉ trong toàn bộ lịch sử Git, cú pháp quy trình và hành vi khởi động. `verify-windows-integration.ps1` xác minh đầy đủ tệp phông, tạo control Windows thật và thử 13 ngôn ngữ, ba tầng cửa sổ cùng việc thu hồi handle GDI/USER. `reproducible-build.ps1` xây hai lần ba bản phát hành và SBOM rồi so sánh tổng kiểm.

AutoHotkey và Ahk2Exe không được khóa sẵn trong kho mã. Mỗi bản phát hành thủ công sẽ truy vấn bản AutoHotkey ổn định mới nhất và bản Ahk2Exe mới nhất, cố định một ảnh chụp đã giải quyết rồi dùng chính nó cho kiểm thử, hai bản dựng, SBOM và đóng gói. Công cụ kiểm tra như actionlint và Gitleaks vẫn được khóa phiên bản. Bản phát hành lưu phiên bản, nguồn, commit và SHA-256 thực tế. Xem [Thông báo phần mềm bên thứ ba](project/THIRD_PARTY_NOTICES.en.md).

## 4. Phát hành và đóng góp

Thay đổi người dùng nhìn thấy phải được cập nhật trong mọi README bản địa hóa và nhật ký thay đổi. Dùng [mẫu nhật ký thay đổi](en/changelog-template.md) cho phiên bản mới và mô tả phần thêm, cải thiện, sửa lỗi có thể quan sát, thay vì sao chép thông điệp commit hoặc tên lớp nội bộ.

Xem [quy trình phát hành](en/release-process.md) và [danh sách kiểm tra công khai](en/publication-checklist.md). Pull Request thông thường không được tạo thẻ phiên bản hay viết lại thẻ đã phát hành. Issue và Pull Request nên có cách tái hiện, rủi ro và bằng chứng xác minh; với cửa sổ, DPI, biểu tượng hoặc chế độ tối, hãy nêu phiên bản Windows và tỷ lệ thật đã thử. Xem [Hướng dẫn đóng góp](../.github/CONTRIBUTING.en.md) và [Quản trị dự án](project/GOVERNANCE.en.md).

Mã dự án được phát hành theo [MIT License](../LICENSE). Thành phần nhúng hoặc đi kèm vẫn theo giấy phép riêng; gói phát hành có giấy phép AutoHotkey và kho lưu mã nguồn tương ứng. PingFang, SF Pro Text và Apple SD Gothic Neo được phân phối theo quyền thương mại mà chủ dự án nắm giữ và không thuộc MIT License.
