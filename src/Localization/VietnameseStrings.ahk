; vi-VN 本地化词条目录。
; 本目录由模型直接依据简体中文稳定键逐条翻译；生成步骤仅处理转义与格式。

class VietnameseStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Nhấn")
        catalog.Set(
            "`n位置：{1}",
                "`nVị trí: {1}")
        catalog.Set(
            "`r`n      影响：该守护对象本次未加入守护列表。",
                "`r`n      Ảnh hưởng: mục này không được thêm vào danh sách giám sát trong lần chạy này.")
        catalog.Set(
            "`r`n      目标：{1}",
                "`r`n      Đích: {1}")
        catalog.Set(
            "`r`n      问题：{1}：{2}",
                "`r`n      Vấn đề: {1}: {2}")
        catalog.Set(
            "`r`n  [{1}] 位置：[{2}] {3}",
                "`r`n  [{1}] Vị trí: [{2}] {3}")
        catalog.Set(
            "`r`n  处理建议：确认目标路径后，可在主界面重新添加该守护对象；也可退出小助手后检查上述配置位置。后续保存配置时，损坏记录会转存到 [Recovery]，不会被静默删除。",
                "`r`n  Cách xử lý: xác nhận đường dẫn đích rồi thêm lại mục này từ cửa sổ chính`; hoặc thoát trợ lý và kiểm tra các vị trí cấu hình nêu trên. Ở lần lưu cấu hình tiếp theo, bản ghi bị hỏng sẽ được chuyển vào [Recovery] thay vì bị xóa mà không thông báo.")
        catalog.Set(
            "`r`n  配置文件：{1}",
                "`r`n  Tệp cấu hình: {1}")
        catalog.Set(
            "   ⚠️ 配置未保存",
                "   ⚠️ Cấu hình chưa được lưu")
        catalog.Set(
            "  --maintenance-begin `"目标完整路径`"    开始维护",
                "  --maintenance-begin `"đường dẫn đầy đủ của đích`"    Bắt đầu bảo trì")
        catalog.Set(
            "  --maintenance-end `"目标完整路径`"      结束维护",
                "  --maintenance-end `"đường dẫn đầy đủ của đích`"      Kết thúc bảo trì")
        catalog.Set(
            " 已保留并保存此前添加的 {1} 个守护对象。",
                " Đã giữ lại và lưu {1} mục giám sát được thêm trước đó.")
        catalog.Set(
            " 扫描达到时间或数量上限，结果已截断。",
                " Quá trình quét đã đạt giới hạn thời gian hoặc số lượng nên kết quả đã bị cắt bớt.")
        catalog.Set(
            "`; AllowForceTerminate：正常退出超时后是否允许强制结束进程。",
                "`; AllowForceTerminate: có cho phép buộc kết thúc tiến trình sau khi hết thời gian chờ thoát bình thường hay không.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应，值为软件升级保护的 <HEX> 编码结构。",
                "`; Mỗi mục AppN tương ứng với mục cùng tên trong [Apps]. Giá trị của nó là cấu trúc bảo vệ khi cập nhật được mã hóa theo dạng <HEX>.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应；留空时使用目标自身的名称和图标。",
                "`; Mỗi mục AppN tương ứng với mục cùng tên trong [Apps]. Mục để trống sẽ dùng tên và biểu tượng của chính đích.")
        catalog.Set(
            "`; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。",
                "`; CheckInterval: khoảng thời gian kiểm tra trạng thái, tính bằng mili giây`; phạm vi 500～86400000.")
        catalog.Set(
            "`; CheckUpdatesOnStartup：启动后是否在后台检查小助手新版。",
                "`; CheckUpdatesOnStartup: có kiểm tra phiên bản trợ lý mới trong nền sau khi khởi động hay không.")
        catalog.Set(
            "`; ClearLogsOnStartup：启动时是否清空历史日志。",
                "`; ClearLogsOnStartup: có xóa nhật ký cũ khi khởi động hay không.")
        catalog.Set(
            "`; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col1W: chiều rộng cột đầu tiên của danh sách chính, được lưu theo pixel lô-gic ở 96 DPI.")
        catalog.Set(
            "`; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col2W: chiều rộng cột thứ hai của danh sách chính, được lưu theo pixel lô-gic ở 96 DPI.")
        catalog.Set(
            "`; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。",
                "`; CtrlCWaitSeconds: số giây chờ tối đa sau khi ứng dụng dòng lệnh nhận Ctrl+C`; phạm vi 1～60.")
        catalog.Set(
            "`; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。",
                "`; GracefulStopSeconds: số giây chờ tối đa để ứng dụng có cửa sổ thoát bình thường`; phạm vi 1～300.")
        catalog.Set(
            "`; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。",
                "`; GuiH: chiều cao cửa sổ chính, được lưu theo pixel lô-gic ở 96 DPI.")
        catalog.Set(
            "`; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。",
                "`; GuiW: chiều rộng cửa sổ chính, được lưu theo pixel lô-gic ở 96 DPI.")
        catalog.Set(
            "`; LogDirectory：留空时使用系统临时目录下的 ProcessWatchdogLogs。",
                "`; LogDirectory: để trống để dùng thư mục ProcessWatchdogLogs trong thư mục tạm của hệ thống.")
        catalog.Set(
            "`; LogMaxEntries：日志界面保留条数，范围 50～10000。",
                "`; LogMaxEntries: số mục được giữ lại trong cửa sổ nhật ký`; phạm vi 50～10000.")
        catalog.Set(
            "`; LogRetentionDays：日志文件保留天数，范围 1～3650。",
                "`; LogRetentionDays: số ngày giữ tệp nhật ký`; phạm vi 1～3650.")
        catalog.Set(
            "`; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。",
                "`; RecursiveBatchImport: có quét đệ quy thư mục con khi nhập hàng loạt một thư mục hay không.")
        catalog.Set(
            "`; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。",
                "`; RetrySequence: thời gian chờ khởi động lại tính bằng giây, phân cách bằng dấu phẩy`; tối đa 10 giá trị, mỗi giá trị trong phạm vi 1～86400.")
        catalog.Set(
            "`; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。",
                "`; ShowAfterReload: cờ tải lại nội bộ`; tự động trở về 0 sau khi tải lại hoàn tất.")
        catalog.Set(
            "`; ShowAtStartup：启动后是否显示主窗口。",
                "`; ShowAtStartup: có hiển thị cửa sổ chính sau khi khởi động hay không.")
        catalog.Set(
            "`; UiLanguage：界面语言；auto 表示跟随系统，也可填写受支持的语言代码。",
                "`; UiLanguage: ngôn ngữ giao diện`; auto nghĩa là theo hệ thống, hoặc có thể nhập mã ngôn ngữ được hỗ trợ.")
        catalog.Set(
            "`; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。",
                "`; Chỉ lưu tên hiển thị và nguồn biểu tượng trên cửa sổ chính`; không ảnh hưởng đến nhận diện tiến trình, khởi chạy hay bảo vệ khi cập nhật.")
        catalog.Set(
            "`; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
                "`; Các trường nội bộ gồm Enabled, RootIsCustom, DetectionSeconds, StableSeconds, MaxWaitSeconds, InstallRoot và Actor.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。",
                "`; Giá trị luận lý dùng 1 cho bật và 0 cho tắt. Nên ưu tiên thay đổi trong cửa sổ cài đặt.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。",
                "`; Giá trị luận lý dùng 1 cho bật và 0 cho tắt`; nội dung <HEX> được phần mềm tự động mã hóa và giải mã.")
        catalog.Set(
            "`; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。",
                "`; Nên thay đổi trong cửa sổ “Bảo vệ khi cập nhật”, không chỉnh sửa trực tiếp nội dung đã mã hóa.")
        catalog.Set(
            "`; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。",
                "`; Bản ghi giám sát không thể phân tích an toàn sẽ được tạm giữ tại đây để tránh mất dữ liệu mà không thông báo`; thông thường không cần sửa thủ công.")
        catalog.Set(
            "`; 本区保存运行参数；以分号开头的注释不会参与软件读取。",
                "`; Phần này lưu các tham số chạy`; chú thích bắt đầu bằng dấu chấm phẩy sẽ bị bỏ qua khi phần mềm đọc tệp.")
        catalog.Set(
            "`; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
                "`; Định dạng: trạng thái bật｜chạy với quyền quản trị viên｜đường dẫn đích｜thư mục làm việc｜đối số khởi chạy｜biến môi trường｜đích thực của lối tắt｜cờ đích thủ công｜đối số lối tắt.")
        catalog.Set(
            "`; 每个 AppN 对应一个守护对象，九个字段使用竖线分隔。",
                "`; Mỗi AppN tương ứng với một mục giám sát`; chín trường được phân cách bằng dấu gạch đứng.")
        catalog.Set(
            "DPI 变化后刷新图标失败：{1}",
                "Không thể làm mới biểu tượng sau khi DPI thay đổi: {1}")
        catalog.Set(
            "DPI 变化后重建图标列表失败：{1}",
                "Không thể dựng lại danh sách biểu tượng sau khi DPI thay đổi: {1}")
        catalog.Set(
            "DPI 图标重建回调无效",
                "Hàm gọi lại để dựng lại biểu tượng theo DPI không hợp lệ")
        catalog.Set(
            "{1} 条监控配置未载入，相关守护对象当前不会被守护。点击查看具体位置和原因。",
                "Không thể nạp {1} bản ghi cấu hình giám sát nên các mục liên quan hiện không được bảo vệ. Bấm để xem vị trí và nguyên nhân cụ thể.")
        catalog.Set(
            "• Ahk2Exe 只在发布服务器上用于生成 EXE，不随小助手安装，普通用户和源码运行用户都不需要维护它。",
                "• Ahk2Exe chỉ được dùng trên máy chủ phát hành để tạo EXE. Công cụ này không được cài cùng trợ lý và cả người dùng thông thường lẫn người chạy phiên bản mã nguồn đều không cần bảo trì nó.")
        catalog.Set(
            "• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。",
                "• Ctrl+A chọn tất cả. Esc sẽ bỏ vùng chọn trước`; khi không có mục nào được chọn, nhấn Esc lần nữa sẽ ẩn cửa sổ chính.")
        catalog.Set(
            "• EXE 版已内嵌该版本发布时验证通过的 AutoHotkey；更新完整小助手发行包时，内嵌运行时会一同更新，电脑无需另装 AutoHotkey。",
                "• Phiên bản EXE nhúng AutoHotkey đã được kiểm thử cho bản phát hành đó. Khi cập nhật toàn bộ gói phát hành của trợ lý, môi trường chạy nhúng cũng được cập nhật`; máy tính không cần cài AutoHotkey riêng.")
        catalog.Set(
            "• EXE 版更新完整编译包；Git 源码版仅在受跟踪文件无修改且可快速前进时更新；其他源码版使用源码发行包。",
                "• Phiên bản EXE cập nhật bằng gói đã biên dịch đầy đủ. Bản mã nguồn Git chỉ cập nhật khi các tệp được theo dõi không có thay đổi và có thể fast-forward đến thẻ phát hành. Các bản mã nguồn khác dùng gói phát hành mã nguồn.")
        catalog.Set(
            "• “监控与启动”可控制是否在启动时后台检查新版；“通用”可随时手动检查。检查过程不会阻塞主界面。",
                "• “Giám sát và khởi động” điều khiển việc kiểm tra phiên bản mới trong nền khi khởi động`; “Chung” cho phép kiểm tra thủ công bất cứ lúc nào. Quá trình kiểm tra không làm cửa sổ chính bị treo.")
        catalog.Set(
            "• 主界面的“日志”显示本次运行中的监控、重启、升级保护和操作记录，并会自动更新。",
                "• “Nhật ký” trên cửa sổ chính hiển thị các bản ghi giám sát, khởi động lại, bảo vệ khi cập nhật và thao tác trong phiên chạy hiện tại, đồng thời tự động cập nhật.")
        catalog.Set(
            "• 也可将文件或文件夹直接拖放到主列表；已经存在的守护对象不会重复添加。",
                "• Bạn cũng có thể kéo thả trực tiếp tệp hoặc thư mục vào danh sách chính`; mục đã tồn tại sẽ không được thêm trùng.")
        catalog.Set(
            "• 停止：设置窗口程序和命令行程序的退出等待，以及是否允许强制终止。",
                "• Dừng: đặt thời gian chờ thoát cho ứng dụng có cửa sổ và ứng dụng dòng lệnh, cùng việc có cho phép buộc kết thúc hay không.")
        catalog.Set(
            "• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。",
                "• Sau khi đóng cửa sổ chính, trợ lý tiếp tục chạy trong khay hệ thống. Menu khay cho phép hiển thị lại cửa sổ chính, tải lại hoặc thoát chương trình.")
        catalog.Set(
            "• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。",
                "• Khi thời gian chờ cập nhật hết hoặc bị nhận diện sai, có thể chọn “Kết thúc chờ cập nhật và tiếp tục giám sát”`; trước khi tiếp tục, tệp đích vẫn được kiểm tra để bảo đảm có thể khởi chạy an toàn.")
        catalog.Set(
            "• 单击选择守护对象；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。",
                "• Bấm để chọn mục`; giữ Ctrl hoặc Shift để chọn nhiều mục`; kéo hàng trong danh sách để thay đổi thứ tự giám sát.")
        catalog.Set(
            "• 双击守护对象或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。",
                "• Bấm đúp vào mục hoặc nhấn F2 để sửa đường dẫn đầy đủ. Delete để xóa, Ctrl+Z để hoàn tác, Ctrl+Shift+Z hoặc Ctrl+Y để làm lại.")
        catalog.Set(
            "• 发现新版后会先询问；确认后校验完整发行包，退出当前实例、替换受管文件并自动重启，不会覆盖个人配置和升级保护会话。",
                "• Khi phát hiện phiên bản mới, trợ lý sẽ hỏi trước. Sau khi xác nhận, trợ lý kiểm tra toàn bộ gói phát hành, thoát phiên bản đang chạy, thay thế tệp được quản lý rồi tự khởi động lại mà không ghi đè cấu hình cá nhân hay phiên bảo vệ khi cập nhật.")
        catalog.Set(
            "• 可控的更新脚本可显式发送维护指令：",
                "• Tập lệnh cập nhật do bạn kiểm soát có thể gửi lệnh bảo trì tường minh:")
        catalog.Set(
            "• 在守护对象右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。",
                "• Mở “Bảo vệ khi cập nhật” từ menu chuột phải của mục để điều chỉnh thư mục cài đặt, thời gian phát hiện thoát, thời gian chờ tệp ổn định và thời gian chờ cập nhật tối đa, hoặc xóa dấu hiệu nhận dạng trình cập nhật đã học.")
        catalog.Set(
            "• 多个守护对象状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。",
                "• Khi mọi mục được chọn có cùng trạng thái, nút “Tạm dừng” sẽ tạm dừng hoặc tiếp tục tất cả cùng lúc. Nếu trạng thái khác nhau, từng mục sẽ được chuyển đổi riêng.")
        catalog.Set(
            "• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。",
                "• Trợ lý đối chiếu đường dẫn đích hoặc dòng lệnh để tránh nhận diện sai khi chỉ dựa vào tên tiến trình.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“通用”页会同时显示当前小助手版本、运行形态和实际运行时版本。",
                "• Phiên bản trợ lý và phiên bản AutoHotkey độc lập với nhau`; trang “Chung” hiển thị đồng thời phiên bản trợ lý, hình thức chạy và phiên bản môi trường chạy thực tế.")
        catalog.Set(
            "• 程序搜索：仅使用 Everything 服务并显示全部匹配结果；使用前请保持 Everything 正在运行。",
                "• Tìm kiếm chương trình: chỉ sử dụng dịch vụ Everything và hiển thị toàn bộ kết quả phù hợp. Hãy bảo đảm Everything đang chạy trước khi tìm kiếm.")
        catalog.Set(
            "• 日志：设置运行日志内存上限、批处理输出日志的保存目录、保留时间和启动时清理策略。",
                "• Nhật ký: đặt giới hạn số bản ghi hoạt động trong bộ nhớ, thư mục lưu nhật ký đầu ra lô, thời gian lưu giữ và cách dọn dẹp khi khởi động.")
        catalog.Set(
            "• 暂停守护对象会取消它的重试和升级检测；恢复后会重新检查目标状态。",
                "• Tạm dừng một mục sẽ hủy lần thử lại và phát hiện cập nhật của mục đó`; khi tiếp tục, trạng thái đích sẽ được kiểm tra lại.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“重启等待序列”依次重试；连续失败时采用后续等待时间，避免频繁拉起。",
                "• Sau khi phát hiện đích dừng, trợ lý xác nhận trạng thái rồi thử lại lần lượt theo “Chuỗi thời gian chờ khởi động lại”. Khi liên tục thất bại, thời gian chờ sau được dùng để tránh vòng lặp khởi động quá nhanh.")
        catalog.Set(
            "• 每次正式发布开始时都会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版（可能为预发布），冻结本次版本后完成全套测试；只有通过才生成发行包。",
                "• Mỗi lần bắt đầu một bản phát hành chính thức, phiên bản ổn định mới nhất của AutoHotkey và bản phát hành mới nhất của Ahk2Exe（có thể là bản phát hành trước）được chọn lại và cố định cho bản đó. Gói phát hành chỉ được tạo sau khi toàn bộ kiểm thử đạt yêu cầu.")
        catalog.Set(
            "• 源码版使用电脑当前安装的 AutoHotkey；小助手更新只更新项目源码，不会安装或升级本机解释器。",
                "• Phiên bản mã nguồn dùng AutoHotkey đang được cài trên máy tính. Cập nhật trợ lý chỉ thay đổi mã nguồn dự án, không cài đặt hay cập nhật trình thông dịch cục bộ.")
        catalog.Set(
            "• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。",
                "• Bấm “Thêm” để tìm ứng dụng, hoặc chọn ứng dụng, tập lệnh, lối tắt hay thư mục.")
        catalog.Set(
            "• 界面语言和字体可在“通用”中手动切换；保存后立即更新主窗口、菜单和托盘，无需重新启动。",
                "• Có thể đổi ngôn ngữ và phông chữ giao diện trong mục “Chung”. Khi lưu, cửa sổ chính, menu và khay hệ thống được cập nhật ngay mà không cần khởi động lại.")
        catalog.Set(
            "• 监控与启动：设置状态检查间隔、重启等待序列、启动后是否显示主窗口、是否检查小助手更新，以及文件夹批量导入是否递归。",
                "• Giám sát và khởi động: đặt khoảng thời gian kiểm tra trạng thái, chuỗi thời gian chờ khởi động lại, có hiển thị cửa sổ chính và kiểm tra bản cập nhật trợ lý sau khi khởi động hay không, cùng việc nhập thư mục có quét đệ quy hay không.")
        catalog.Set(
            "• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。",
                "• Sau khi xác nhận cập nhật, tính năng tự khởi chạy sẽ tạm dừng. Khi hoạt động liên quan kết thúc và tệp đích ổn định, giám sát sẽ tự động tiếp tục. Dấu hiệu nhận dạng trình cập nhật phát hiện trong quá trình cập nhật thực tế sẽ được tự động ghi nhớ.")
        catalog.Set(
            "• 程序：EXE、COM、MSC。",
                "• Ứng dụng: EXE, COM, MSC.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，并可立即检查小助手更新。",
                "• Chung: tạo lối tắt trên màn hình nền và menu Bắt đầu, bật hoặc tắt tự khởi động bằng tác vụ theo lịch, và kiểm tra bản cập nhật trợ lý ngay lập tức.")
        catalog.Set(
            "• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。",
                "• Tập lệnh: AHK, Python, JavaScript, VBScript, PowerShell, tệp lô, Ruby, Perl, PHP, Lua, JAR, Shell và các loại khác.")
        catalog.Set(
            "• 软件升级保护默认关闭。需要时在守护对象右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。",
                "• Bảo vệ khi cập nhật mặc định bị tắt. Khi cần, mở “Bảo vệ khi cập nhật” từ menu chuột phải của mục, chọn “Tự động nhận diện cập nhật và bảo vệ quá trình khởi động”, rồi lưu.")
        catalog.Set(
            "• 选中守护对象后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。",
                "• Sau khi chọn mục, bạn có thể tạm dừng, tiếp tục hoặc xóa. Tạm dừng chỉ dừng giám sát, không đóng đích đang chạy.")
        catalog.Set(
            "• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控与启动”控制。",
                "• Chọn một thư mục sẽ nhập hàng loạt các tệp được hỗ trợ trong đó`; việc có quét thư mục con hay không được điều khiển trong “Giám sát và khởi động” thuộc “Cài đặt”.")
        catalog.Set(
            "• 守护对象右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。",
                "• “Xem nhật ký hoạt động” trong menu chuột phải của mục dùng để mở nhật ký đầu ra do đích BAT/CMD tạo. Với loại khác hoặc khi nhật ký chưa được tạo, trợ lý sẽ báo không tìm thấy tệp.")
        catalog.Set(
            "⏳ 正在结束运行...",
                "⏳ Đang kết thúc mục tiêu...")
        catalog.Set(
            "⏳ 判断是否正在升级",
                "⏳ Đang xác định có cập nhật hay không")
        catalog.Set(
            "⏳ 升级完成，准备恢复",
                "⏳ Cập nhật hoàn tất`; đang chuẩn bị tiếp tục")
        catalog.Set(
            "⏳ 启动倒计时 {1} 秒",
                "⏳ Khởi động sau {1} giây")
        catalog.Set(
            "⏳ 启动失败，稍后自动重试",
                "⏳ Khởi động thất bại`; sẽ tự thử lại sau")
        catalog.Set(
            "⏳ 确认升级文件稳定",
                "⏳ Đang xác nhận tệp ổn định sau cập nhật")
        catalog.Set(
            "⏳ 确认升级文件稳定 {1}s",
                "⏳ Đang xác nhận tệp ổn định sau cập nhật {1}s")
        catalog.Set(
            "⏳ 稍后自动重试 {1} 秒",
                "⏳ Tự thử lại sau {1} giây")
        catalog.Set(
            "⏳ 等待安全启动条件",
                "⏳ Đang chờ điều kiện khởi động an toàn")
        catalog.Set(
            "⏳ 等待进程状态...",
                "⏳ Đang chờ trạng thái tiến trình...")
        catalog.Set(
            "⏳ 重试倒计时 {1} 秒",
                "⏳ Thử lại sau {1} giây")
        catalog.Set(
            "⏳ 验证运行状态...",
                "⏳ Đang xác minh trạng thái chạy...")
        catalog.Set(
            "⏸️ 已暂停",
                "⏸️ Đã tạm dừng")
        catalog.Set(
            "⏸️ 暂停",
                "⏸️ Tạm dừng")
        catalog.Set(
            "▶️ 恢复",
                "▶️ Tiếp tục")
        catalog.Set(
            "⚙️ 启动参数：{1}`n",
                "⚙️ Đối số khởi chạy: {1}`n")
        catalog.Set(
            "⚠️ 升级等待超时",
                "⚠️ Hết thời gian chờ cập nhật")
        catalog.Set(
            "⚠️ 疑似停止",
                "⚠️ Có thể đã dừng")
        catalog.Set(
            "⚠️ 运行中（权限不符）",
                "⚠️ Đang chạy（quyền không khớp）")
        catalog.Set(
            "✅ 已启动（非驻留目标）",
                "✅ Đã khởi động（đích không thường trú）")
        catalog.Set(
            "✅ 运行中",
                "✅ Đang chạy")
        catalog.Set(
            "✅ 运行：{1}   🚫 停止：{2}   ⏳ 恢复：{3}   🔄 升级：{4}   ⏸️ 暂停：{5}   ❌ 失效：{6}   ｜   🎯 总计：{7}",
                "✅ Đang chạy: {1}   🚫 Đã dừng: {2}   ⏳ Đang phục hồi: {3}   🔄 Đang cập nhật: {4}   ⏸️ Tạm dừng: {5}   ❌ Không hợp lệ: {6}   ｜   🎯 Tổng: {7}")
        catalog.Set(
            "✒️ 编辑完整路径（F2）",
                "✒️ Sửa đường dẫn đầy đủ（F2）")
        catalog.Set(
            "确 定",
                "OK")
        catalog.Set(
            "取 消",
                "Hủy")
        catalog.Set(
            "❌ 无法结束运行",
                "❌ Không thể kết thúc mục tiêu")
        catalog.Set(
            "❌ 目标不存在",
                "❌ Không tìm thấy đích")
        catalog.Set(
            "❌ 程序不存在",
                "❌ Không tìm thấy ứng dụng")
        catalog.Set(
            "❌ 脚本不存在",
                "❌ Không tìm thấy tập lệnh")
        catalog.Set(
            "➕ 添加",
                "➕ Thêm")
        catalog.Set(
            "。",
                ".")
        catalog.Set(
            "一、快速上手",
                "1. Bắt đầu nhanh")
        catalog.Set(
            "七、软件升级保护",
                "7. Bảo vệ khi cập nhật")
        catalog.Set(
            "三、主界面操作",
                "3. Thao tác trên cửa sổ chính")
        catalog.Set(
            "不允许的升级保护阶段转换：{1}",
                "Chuyển giai đoạn bảo vệ khi cập nhật không được phép: {1}")
        catalog.Set(
            "不支持的启动规格类型",
                "Loại đặc tả khởi chạy không được hỗ trợ")
        catalog.Set(
            "不支持的图标格式",
                "Định dạng biểu tượng không được hỗ trợ")
        catalog.Set(
            "不是当前 <HEX> 编码格式",
                "Không phải định dạng mã hóa <HEX> hiện tại")
        catalog.Set(
            "与已加载守护对象重复，或目标格式无效",
                "Trùng với mục đã nạp hoặc định dạng đích không hợp lệ")
        catalog.Set(
            "主进程监控",
                "Giám sát tiến trình chính")
        catalog.Set(
            "主进程监控异常：{1}",
                "Lỗi giám sát tiến trình chính: {1}")
        catalog.Set(
            "二、支持的守护对象",
                "2. Đích được hỗ trợ")
        catalog.Set(
            "五、设置",
                "5. Cài đặt")
        catalog.Set(
            "代码热重载完毕，界面已恢复显示。",
                "Đã tải nóng lại mã`; giao diện được hiển thị trở lại.")
        catalog.Set(
            "仲裁期间捕获到升级活动",
                "Phát hiện hoạt động cập nhật trong lúc phân xử")
        catalog.Set(
            "使用说明",
                "Hướng dẫn sử dụng")
        catalog.Set(
            "恢复默认",
                "Khôi phục mặc định")
        catalog.Set(
            "保存",
                "Lưu")
        catalog.Set(
            "保存升级保护恢复状态失败：{1}",
                "Không thể lưu trạng thái phục hồi của bảo vệ khi cập nhật: {1}")
        catalog.Set(
            "保存失败",
                "Lưu thất bại")
        catalog.Set(
            "保存显示设置失败，请查看运行日志。",
                "Không thể lưu cài đặt hiển thị. Hãy xem nhật ký hoạt động.")
        catalog.Set(
            "保存监控配置失败：{1}",
                "Không thể lưu cấu hình giám sát: {1}")
        catalog.Set(
            "保存窗口布局失败：{1}",
                "Không thể lưu bố cục cửa sổ: {1}")
        catalog.Set(
            "保存设置失败，请查看运行日志。",
                "Không thể lưu cài đặt. Hãy xem nhật ký hoạt động.")
        catalog.Set(
            "保存软件升级保护设置失败，请查看运行日志。",
                "Không thể lưu cài đặt bảo vệ khi cập nhật. Hãy xem nhật ký hoạt động.")
        catalog.Set(
            "保存运行参数失败：{1}",
                "Không thể lưu tham số chạy: {1}")
        catalog.Set(
            "值不是 0 或 1",
                "Giá trị không phải 0 hoặc 1")
        catalog.Set(
            "停止",
                "Dừng")
        catalog.Set(
            "八、日志与托盘",
                "8. Nhật ký và khay hệ thống")
        catalog.Set(
            "六、版本与小助手自身更新",
                "6. Phiên bản và cập nhật trợ lý")
        catalog.Set(
            "内容为空",
                "Nội dung trống")
        catalog.Set(
            "内容无法解析",
                "Không thể phân tích nội dung")
        catalog.Set(
            "创建快捷方式失败：{1}",
                "Không thể tạo lối tắt: {1}")
        catalog.Set(
            "初始化...",
                "Đang khởi tạo...")
        catalog.Set(
            "删除选中的守护对象（支持多选，可撤销）`n快捷键：Delete",
                "Xóa các mục giám sát đã chọn（hỗ trợ chọn nhiều và hoàn tác）`nPhím: Delete")
        catalog.Set(
            "刷新主窗口状态失败，已暂停界面倒计时刷新：{1}",
                "Không thể làm mới trạng thái cửa sổ chính`; đã tạm dừng cập nhật đếm ngược: {1}")
        catalog.Set(
            "刷新运行日志窗口失败，已暂停自动刷新：{1}",
                "Không thể làm mới cửa sổ nhật ký hoạt động`; đã tạm dừng tự động làm mới: {1}")
        catalog.Set(
            "升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。",
                "Bảo vệ khi cập nhật chỉ hỗ trợ ứng dụng hoặc tập lệnh có đường dẫn đầy đủ hợp lệ. Thư mục cài đặt phải tồn tại và chứa tệp đích.")
        catalog.Set(
            "升级保护仍在进行",
                "Bảo vệ khi cập nhật vẫn đang hoạt động")
        catalog.Set(
            "升级保护初始化时无法建立进程基线，将在下一轮重试。",
                "Không thể lập đường cơ sở tiến trình khi khởi tạo bảo vệ cập nhật`; sẽ thử lại ở chu kỳ sau.")
        catalog.Set(
            "升级保护协调器未能初始化，核心守护不会启动。",
                "Không thể khởi tạo bộ điều phối bảo vệ khi cập nhật nên chức năng giám sát cốt lõi sẽ không khởi động.")
        catalog.Set(
            "升级保护配置",
                "Cấu hình bảo vệ khi cập nhật")
        catalog.Set(
            "升级文件监听",
                "Theo dõi tệp cập nhật")
        catalog.Set(
            "升级文件监听异常（{1}）：{2}",
                "Lỗi theo dõi tệp cập nhật（{1}）: {2}")
        catalog.Set(
            "升级文件监听异常：{1}",
                "Lỗi theo dõi tệp cập nhật: {1}")
        catalog.Set(
            "升级等待已超时",
                "Đã hết thời gian chờ cập nhật")
        catalog.Set(
            "升级进程扫描",
                "Quét tiến trình cập nhật")
        catalog.Set(
            "升级进程扫描异常：{1}",
                "Lỗi quét tiến trình cập nhật: {1}")
        catalog.Set(
            "参数错误",
                "Lỗi tham số")
        catalog.Set(
            "发现小助手新版本：{1}（当前版本：{2}）",
                "Có phiên bản trợ lý mới: {1}（hiện tại: {2}）")
        catalog.Set(
            "发现新版本 {1}，当前版本为 {2}。{3}{3}{4}{3}{3}是否立即更新？",
                "Có phiên bản mới {1}`; phiên bản hiện tại là {2}.{3}{3}{4}{3}{3}Cập nhật ngay?")
        catalog.Set(
            "取消",
                "Hủy")
        catalog.Set(
            "名称",
                "Tên")
        catalog.Set(
            "后台任务耗时较长：{1}，本次 {2} 毫秒",
                "Tác vụ nền mất nhiều thời gian: {1}`; lần này {2} mili giây")
        catalog.Set(
            "后台扫描进程未返回 PID",
                "Tiến trình quét nền không trả về PID")
        catalog.Set(
            "后台调度任务异常（{1}）：{2}",
                "Lỗi tác vụ lập lịch nền（{1}）: {2}")
        catalog.Set(
            "后台进程快照为空或不完整，已忽略本次结果并安排重试。",
                "Ảnh chụp tiến trình nền trống hoặc không đầy đủ. Kết quả lần này đã bị bỏ qua và một lần thử lại đã được lên lịch.")
        catalog.Set(
            "后台进程快照已确认",
                "Đã xác nhận ảnh chụp tiến trình nền")
        catalog.Set(
            "后台进程快照未及时返回，已等待完整检测窗口",
                "Ảnh chụp tiến trình nền không trả về kịp thời`; đã chờ hết toàn bộ khoảng thời gian phát hiện")
        catalog.Set(
            "启动前没有可用的启动目标，已停止重试：{1}{2}",
                "Không có đích khởi chạy khả dụng trước khi khởi động`; đã dừng thử lại: {1}{2}")
        catalog.Set(
            "启动参数",
                "Đối số khởi chạy")
        catalog.Set(
            "启动参数（Args）：",
                "Đối số khởi chạy（Args）:")
        catalog.Set(
            "启动器需要 LaunchSpec",
                "Trình khởi chạy cần LaunchSpec")
        catalog.Set(
            "启动失败",
                "Khởi động thất bại")
        catalog.Set(
            "启动失败 [{1}/{2}]：{3} - {4}",
                "Khởi động thất bại [{1}/{2}]: {3} - {4}")
        catalog.Set(
            "启动成功且运行稳定：{1}",
                "Khởi động thành công và chạy ổn định: {1}")
        catalog.Set(
            "启动批量导入失败",
                "Không thể bắt đầu nhập hàng loạt")
        catalog.Set(
            "启动时检查小助手更新",
                "Kiểm tra cập nhật trợ lý khi khởi động")
        catalog.Set(
            "启动时清空批处理日志",
                "Xóa nhật ký đầu ra lô khi khởi động")
        catalog.Set(
            "启动目标不可用",
                "Đích khởi chạy không khả dụng")
        catalog.Set(
            "启动目标不存在",
                "Đích khởi chạy không tồn tại")
        catalog.Set(
            "启用状态",
                "Trạng thái bật")
        catalog.Set(
            "四、守护与重启",
                "4. Giám sát và khởi động lại")
        catalog.Set(
            "图标来源无效",
                "Nguồn biểu tượng không hợp lệ")
        catalog.Set(
            "图标来源：",
                "Nguồn biểu tượng:")
        catalog.Set(
            "图标缩放器",
                "Bộ lấy mẫu lại biểu tượng")
        catalog.Set(
            "处理后台进程快照时发生错误：{1}",
                "Đã xảy ra lỗi khi xử lý ảnh chụp tiến trình nền: {1}")
        catalog.Set(
            "处理应用更新结果失败：{1}",
                "Không thể xử lý kết quả cập nhật ứng dụng: {1}")
        catalog.Set(
            "字段数量应为 {1}，实际为 {2}",
                "Cần {1} trường nhưng thực tế có {2}")
        catalog.Set(
            "守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！",
                "Giám sát tiến trình cần quyền đọc ghi hệ thống cấp cao. Hãy chạy chương trình này với quyền quản trị viên.")
        catalog.Set(
            "守护对象：",
                "Đối tượng giám sát:")
        catalog.Set(
            "安全启动门暂缓启动：{1}（{2}）",
                "Cổng khởi động an toàn đã hoãn khởi chạy: {1}（{2}）")
        catalog.Set(
            "安装目录特征",
                "Dấu hiệu thư mục cài đặt")
        catalog.Set(
            "安装足迹目录：",
                "Thư mục cài đặt:")
        catalog.Set(
            "完整路径",
                "Đường dẫn đầy đủ")
        catalog.Set(
            "完整路径：{1}",
                "Đường dẫn đầy đủ: {1}")
        catalog.Set(
            "导出诊断包",
                "Xuất gói chẩn đoán")
        catalog.Set(
            "导出诊断包失败：{1}",
                "Không thể xuất gói chẩn đoán: {1}")
        catalog.Set(
            "将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。",
                "Toàn bộ gói phát hành sẽ được tải xuống và kiểm tra. Sau đó trợ lý sẽ thoát, thay thế tệp chương trình và tự khởi động lại.")
        catalog.Set(
            "将下载并校验源码发行包，保留个人配置后替换源码并自动重启。",
                "Gói phát hành mã nguồn sẽ được tải xuống và kiểm tra. Cấu hình cá nhân được giữ lại trong khi mã nguồn được thay thế, rồi trợ lý tự khởi động lại.")
        catalog.Set(
            "将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。",
                "Kho mã nguồn sẽ được kiểm tra để bảo đảm không có thay đổi chưa commit, sau đó fast-forward đến thẻ phát hành chính thức và tự khởi động lại.")
        catalog.Set(
            "小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。",
                "Trợ lý giám sát ứng dụng, tập lệnh và lối tắt trong nền. Khi đích thoát bất thường, trợ lý khởi động lại theo chuỗi thời gian chờ đã đặt. Đóng cửa sổ chính chỉ ẩn nó vào khay hệ thống, không dừng giám sát.")
        catalog.Set(
            "小助手已是最新版本：{1}",
                "Trợ lý đã là phiên bản mới nhất: {1}")
        catalog.Set(
            "小助手更新",
                "Cập nhật trợ lý")
        catalog.Set(
            "小助手设置",
                "Cài đặt trợ lý")
        catalog.Set(
            "尚未从真实升级过程学习到更新程序特征。",
                "Chưa học được dấu hiệu nhận dạng trình cập nhật nào từ một lần cập nhật thực tế.")
        catalog.Set(
            "展示配置",
                "Cấu hình hiển thị")
        catalog.Set(
            "工作目录",
                "Thư mục làm việc")
        catalog.Set(
            "工作目录（CWD）：",
                "Thư mục làm việc（CWD）:")
        catalog.Set(
            "已从本次升级过程学习更新程序特征：{1}",
                "Dấu hiệu nhận dạng trình cập nhật học được trong lần cập nhật này: {1}")
        catalog.Set(
            "已保存身份",
                "Thông tin nhận dạng đã lưu")
        catalog.Set(
            "已关闭以管理员身份运行：{1}",
                "Đã tắt chạy với quyền quản trị viên: {1}")
        catalog.Set(
            "已创建最高权限的开机自启计划任务（Win10 配置，适配笔记本）。",
                "Đã tạo tác vụ tự khởi động với quyền cao nhất（cấu hình Windows 10, phù hợp máy tính xách tay）.")
        catalog.Set(
            "已创建桌面与开始菜单快捷方式。",
                "Đã tạo lối tắt trên màn hình nền và menu Bắt đầu.")
        catalog.Set(
            "已删除自启计划任务。",
                "Đã xóa tác vụ tự khởi động theo lịch.")
        catalog.Set(
            "已刷新快捷方式内置参数：{1}",
                "Đã làm mới đối số nhúng trong lối tắt: {1}")
        catalog.Set(
            "已刷新快捷方式真实进程（{1}）：{2} -> {3}",
                "Đã làm mới tiến trình thực của lối tắt（{1}）: {2} -> {3}")
        catalog.Set(
            "已发送启动指令：{1}{2}",
                "Đã gửi lệnh khởi chạy: {1}{2}")
        catalog.Set(
            "已取消监控：{1}",
                "Đã hủy giám sát: {1}")
        catalog.Set(
            "已启动批处理并重定向输出到：{1}",
                "Đã khởi động đích lô và chuyển hướng đầu ra đến: {1}")
        catalog.Set(
            "已启动非驻留目标：{1}",
                "Đã khởi động đích không thường trú: {1}")
        catalog.Set(
            "已启用以管理员身份运行：{1}",
                "Đã bật chạy với quyền quản trị viên: {1}")
        catalog.Set(
            "已导出本地诊断包：{1}",
                "Đã xuất gói chẩn đoán cục bộ: {1}")
        catalog.Set(
            "已恢复未完成的升级保护会话：{1}",
                "Đã khôi phục phiên bảo vệ khi cập nhật chưa hoàn tất: {1}")
        catalog.Set(
            "已撤销上一步操作。",
                "Đã hoàn tác thao tác trước.")
        catalog.Set(
            "已更新主窗口显示设置：{1}",
                "Đã cập nhật cài đặt hiển thị của cửa sổ chính: {1}")
        catalog.Set(
            "已更新守护对象路径。",
                "Đã cập nhật đường dẫn của đối tượng giám sát.")
        catalog.Set(
            "已更新软件升级保护设置：{1}",
                "Đã cập nhật cài đặt bảo vệ khi cập nhật: {1}")
        catalog.Set(
            "已添加 {1} 个守护对象。",
                "Đã thêm {1} mục giám sát.")
        catalog.Set(
            "已用完快速重试，将每隔 {1} 秒继续尝试启动：{2}",
                "Đã dùng hết các lần thử nhanh`; sẽ tiếp tục thử khởi động mỗi {1} giây: {2}")
        catalog.Set(
            "已自动学习的更新程序特征：",
                "Dấu hiệu nhận dạng trình cập nhật đã tự học:")
        catalog.Set(
            "已进入软件升级保护：{1}{2}",
                "Đã vào chế độ bảo vệ khi cập nhật: {1}{2}")
        catalog.Set(
            "已重做操作。",
                "Đã làm lại thao tác.")
        catalog.Set(
            "常规终止权限不足，已提权终止进程 PID：{1}",
                "Thao tác kết thúc thông thường không đủ quyền`; đã nâng quyền để kết thúc tiến trình PID {1}.")
        catalog.Set(
            "序号",
                "STT")
        catalog.Set(
            "应用更新助手不存在",
                "Không có trình hỗ trợ cập nhật ứng dụng")
        catalog.Set(
            "应用更新参数无效",
                "Tham số cập nhật ứng dụng không hợp lệ")
        catalog.Set(
            "应用更新安装进程未返回 PID",
                "Tiến trình cài đặt cập nhật ứng dụng không trả về PID")
        catalog.Set(
            "应用更新本地化资源不存在",
                "Không có tài nguyên bản địa hóa cập nhật ứng dụng")
        catalog.Set(
            "应用更新检查进程未返回 PID",
                "Tiến trình kiểm tra cập nhật ứng dụng không trả về PID")
        catalog.Set(
            "守护对象",
                "Đối tượng giám sát")
        catalog.Set(
            "应用资源",
                "Tài nguyên ứng dụng")
        catalog.Set(
            "开机自动启动（计划任务）",
                "Tự khởi động khi đăng nhập（tác vụ theo lịch）")
        catalog.Set(
            "当前陪伴您的已经是最新版本的小助手啦！",
                "Trợ lý đang đồng hành cùng bạn đã là phiên bản mới nhất rồi!")
        catalog.Set(
            "当前应用版本无效",
                "Phiên bản ứng dụng hiện tại không hợp lệ")
        catalog.Set(
            "当前版本：{1}（EXE 版；内嵌 AutoHotkey {2} x64）",
                "Phiên bản hiện tại: {1}（bản EXE`; AutoHotkey {2} x64 được nhúng）")
        catalog.Set(
            "当前版本：{1}（源码版；本机 AutoHotkey {2} x64）",
                "Phiên bản hiện tại: {1}（bản mã nguồn`; AutoHotkey {2} x64 cục bộ）")
        catalog.Set(
            "当前状态：升级活动已结束，正在确认程序文件稳定",
                "Trạng thái hiện tại: hoạt động cập nhật đã kết thúc`; đang xác nhận tệp chương trình ổn định")
        catalog.Set(
            "当前状态：升级等待超时，需要确认后恢复",
                "Trạng thái hiện tại: đã hết thời gian chờ cập nhật`; cần xác nhận trước khi tiếp tục")
        catalog.Set(
            "当前状态：已从上次运行恢复未完成的升级保护",
                "Trạng thái hiện tại: đã khôi phục bảo vệ khi cập nhật chưa hoàn tất từ lần chạy trước")
        catalog.Set(
            "当前状态：已暂停自动启动，正在等待升级完成",
                "Trạng thái hiện tại: đã tạm dừng tự khởi chạy và đang chờ cập nhật hoàn tất")
        catalog.Set(
            "当前状态：显式升级维护已开始，正在等待结束命令",
                "Trạng thái hiện tại: đã bắt đầu bảo trì cập nhật tường minh và đang chờ lệnh kết thúc")
        catalog.Set(
            "当前状态：正在判断本次退出是否由升级引起",
                "Trạng thái hiện tại: đang xác định lần thoát này có do cập nhật gây ra hay không")
        catalog.Set(
            "当前状态：正常守护",
                "Trạng thái hiện tại: giám sát bình thường")
        catalog.Set(
            "快捷方式参数",
                "Đối số lối tắt")
        catalog.Set(
            "快捷方式及已解析目标均不可用",
                "Cả lối tắt lẫn đích đã phân giải đều không khả dụng")
        catalog.Set(
            "快捷方式目标",
                "Đích của lối tắt")
        catalog.Set(
            "快捷方式真实目标",
                "Đích thực đã phân giải của lối tắt")
        catalog.Set(
            "快捷方式真实进程刷新被拒绝，目标已由其它守护对象守护：{1} -> {2}",
                "Từ chối làm mới tiến trình thực của lối tắt vì đích đã được mục khác giám sát: {1} -> {2}")
        catalog.Set(
            "恢复守护：{1}",
                "Đã tiếp tục giám sát: {1}")
        catalog.Set(
            "恢复记录列表无效",
                "Danh sách bản ghi phục hồi không hợp lệ")
        catalog.Set(
            "恢复记录无效",
                "Bản ghi phục hồi không hợp lệ")
        catalog.Set(
            "恢复记录缺少字段：{1}",
                "Bản ghi phục hồi thiếu trường: {1}")
        catalog.Set(
            "成功",
                "Thành công")
        catalog.Set(
            "所选文件夹内未找到支持的程序、脚本或快捷方式。",
                "Không tìm thấy ứng dụng, tập lệnh hoặc lối tắt được hỗ trợ trong thư mục đã chọn.")
        catalog.Set(
            "手动添加守护对象：{1}",
                "Đã thêm mục giám sát thủ công: {1}")
        catalog.Set(
            "已结束运行：{1}",
                "Đã kết thúc mục tiêu: {1}")
        catalog.Set(
            "结束运行失败，目标进程未能停止：{1}",
                "Không thể kết thúc tiến trình đích: {1}")
        catalog.Set(
            "托管窗口生命周期尚未配置",
                "Chưa cấu hình vòng đời cửa sổ được quản lý")
        catalog.Set(
            "托管窗口生命周期适配器无效",
                "Bộ điều hợp vòng đời cửa sổ được quản lý không hợp lệ")
        catalog.Set(
            "扩展设置包含无效数值。`n`n窗口程序关闭等待：1-300 秒`n命令行程序退出等待：1-60 秒`n日志条数：50-10000`n日志保留：1-3650 天",
                "Một hoặc nhiều cài đặt nâng cao không hợp lệ.`n`nThời gian chờ đóng ứng dụng có cửa sổ: 1-300 giây`nThời gian chờ thoát ứng dụng dòng lệnh: 1-60 giây`nSố mục nhật ký: 50-10000`nThời gian lưu nhật ký: 1-3650 ngày")
        catalog.Set(
            "批处理启动需要输出日志路径",
                "Khởi chạy đích lô cần đường dẫn nhật ký đầu ra")
        catalog.Set(
            "批量导入中断",
                "Nhập hàng loạt bị gián đoạn")
        catalog.Set(
            "批量导入完成",
                "Nhập hàng loạt hoàn tất")
        catalog.Set(
            "批量导入已取消，已保留并保存此前添加的 {1} 个守护对象。",
                "Đã hủy nhập hàng loạt. {1} mục giám sát được thêm trước đó đã được giữ lại và lưu.")
        catalog.Set(
            "拒绝修改路径，真实进程已由其它守护对象守护：{1}",
                "Từ chối sửa đường dẫn vì tiến trình thực đã được mục khác giám sát: {1}")
        catalog.Set(
            "拒绝更新路径，已存在相同的守护对象：{1}",
                "Từ chối thay đổi đường dẫn vì đã có một đối tượng giám sát trùng khớp: {1}")
        catalog.Set(
            "按钮绘制器",
                "Bộ vẽ nút")
        catalog.Set(
            "捕获守护对象历史失败：{1}",
                "Không thể ghi lại lịch sử mục giám sát: {1}")
        catalog.Set(
            "提示",
                "Thông báo")
        catalog.Set(
            "⚡️搜索⚡️",
                "⚡️ Tìm kiếm ⚡️")
        catalog.Set(
            "操作计划任务时发生错误！`n`n{1}",
                "Đã xảy ra lỗi khi thao tác tác vụ theo lịch.`n`n{1}")
        catalog.Set(
            "支持的图标与图片",
                "Biểu tượng và hình ảnh được hỗ trợ")
        catalog.Set(
            "支持的程序、脚本与快捷方式",
                "Ứng dụng, tập lệnh và lối tắt được hỗ trợ")
        catalog.Set(
            "支持的程序与脚本",
                "Ứng dụng và tập lệnh được hỗ trợ")
        catalog.Set(
            "收到显式维护开始命令",
                "Đã nhận lệnh bắt đầu bảo trì tường minh")
        catalog.Set(
            "收到显式维护结束命令，开始执行安全恢复检查：{1}",
                "Đã nhận lệnh kết thúc bảo trì tường minh`; bắt đầu kiểm tra tiếp tục an toàn: {1}")
        catalog.Set(
            "整条展示配置",
                "Toàn bộ cấu hình hiển thị")
        catalog.Set(
            "整条记录",
                "Toàn bộ bản ghi")
        catalog.Set(
            "文件稳定等待（秒）：",
                "Thời gian chờ tệp ổn định（giây）:")
        catalog.Set(
            "新脚本未通过 AutoHotkey 解析检查",
                "Tập lệnh mới không vượt qua kiểm tra phân tích AutoHotkey")
        catalog.Set(
            "无法从损坏记录中提取",
                "Không thể trích xuất từ bản ghi bị hỏng")
        catalog.Set(
            "无法停止进程 PID：{1}{2}",
                "Không thể dừng tiến trình PID {1}{2}")
        catalog.Set(
            "无法写入诊断文件：{1}",
                "Không thể ghi tệp chẩn đoán: {1}")
        catalog.Set(
            "无法启动后台文件扫描：{1}",
                "Không thể bắt đầu quét tệp trong nền: {1}")
        catalog.Set(
            "无法启动后台进程快照任务：{1}",
                "Không thể bắt đầu tác vụ chụp tiến trình nền: {1}")
        catalog.Set(
            "无法启动小助手更新安装：{1}",
                "Không thể bắt đầu cài đặt bản cập nhật trợ lý: {1}")
        catalog.Set(
            "无法启动小助手更新检查：{1}",
                "Không thể bắt đầu kiểm tra cập nhật trợ lý: {1}")
        catalog.Set(
            "无法导出诊断包：`n{1}",
                "Không thể xuất gói chẩn đoán:`n{1}")
        catalog.Set(
            "无法建立单实例运行锁，小助手将退出。",
                "Không thể tạo khóa chạy một phiên bản duy nhất. Trợ lý sẽ thoát.")
        catalog.Set(
            "无法开始更新：{1}",
                "Không thể bắt đầu cập nhật: {1}")
        catalog.Set(
            "无法收集此部分诊断信息：{1}",
                "Không thể thu thập phần thông tin chẩn đoán này: {1}")
        catalog.Set(
            "无法检查更新：{1}",
                "Không thể kiểm tra cập nhật: {1}")
        catalog.Set(
            "无法清理后台扫描临时文件：{1}",
                "Không thể dọn tệp tạm của quét nền: {1}")
        catalog.Set(
            "无法清理后台扫描结果文件：{1}",
                "Không thể dọn tệp kết quả quét nền: {1}")
        catalog.Set(
            "无法生成守护对象快照：{1}",
                "Không thể tạo ảnh chụp mục giám sát: {1}")
        catalog.Set(
            "日志",
                "Nhật ký")
        catalog.Set(
            "日志文件不存在：{1}",
                "Tệp nhật ký không tồn tại: {1}")
        catalog.Set("📄 查看批处理输出日志", "📄 Xem nhật ký đầu ra lô")
        catalog.Set("尚未生成批处理输出日志", "Chưa có nhật ký đầu ra lô")
        catalog.Set(
            "小助手只有在启动 BAT 或 CMD 守护对象时才会创建此文件。",
                "Tệp này chỉ được tạo khi trợ lý khởi chạy một mục BAT hoặc CMD.")
        catalog.Set("日志保存位置：", "Vị trí lưu nhật ký:")
        catalog.Set("确定", "Xác nhận")
        catalog.Set(
            "时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间",
                "Cài đặt thời gian không hợp lệ.`n`nThời gian phát hiện thoát: 2-120 giây`nThời gian chờ tệp ổn định: 2-300 giây`nThời gian chờ cập nhật tối đa: 60-86400 giây và phải lớn hơn thời gian chờ ổn định")
        catalog.Set(
            "显式升级维护命令执行异常：{1}",
                "Lỗi khi thực hiện lệnh bảo trì cập nhật tường minh: {1}")
        catalog.Set(
            "显式升级维护命令未找到监控目标：{1}",
                "Lệnh bảo trì cập nhật tường minh không tìm thấy đích giám sát: {1}")
        catalog.Set(
            "显式升级维护命令被忽略，目标未启用升级保护：{1}",
                "Đã bỏ qua lệnh bảo trì cập nhật tường minh vì đích chưa bật bảo vệ khi cập nhật: {1}")
        catalog.Set(
            "显示主界面",
                "Hiển thị cửa sổ chính")
        catalog.Set(
            "显示名称：",
                "Tên hiển thị:")
        catalog.Set(
            "暂停守护：{1}",
                "Đã tạm dừng giám sát: {1}")
        catalog.Set(
            "暂停或恢复选中守护对象，不会退出目标`n支持多选；混合状态时逐项反转`n快捷键：Space",
                "Tạm dừng hoặc tiếp tục giám sát các mục đã chọn mà không thoát đích`nHỗ trợ chọn nhiều`; trạng thái hỗn hợp được chuyển đổi riêng từng mục`nPhím tắt: Space")
        catalog.Set(
            "暂时无法查询进程状态，稍后重试结束运行：{1}",
                "Tạm thời không thể truy vấn trạng thái tiến trình`; sẽ thử kết thúc lại sau: {1}")
        catalog.Set(
            "暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                "Tạm thời không thể đối chiếu tiến trình hiện có`; đã hoãn khởi chạy để tránh phiên bản trùng: {1}")
        catalog.Set(
            "暂时无法结束运行",
                "Tạm thời không thể kết thúc")
        catalog.Set(
            "更新助手已启动，小助手即将退出并完成更新。",
                "Trình hỗ trợ cập nhật đã khởi động. Trợ lý sắp thoát để hoàn tất cập nhật.")
        catalog.Set(
            "更新应用搜索结果失败：{1}",
                "Không thể cập nhật kết quả tìm kiếm ứng dụng: {1}")
        catalog.Set(
            "更新检查未返回结果",
                "Kiểm tra cập nhật không trả về kết quả")
        catalog.Set(
            "更新检查正在进行，请稍候。",
                "Đang kiểm tra cập nhật. Vui lòng chờ.")
        catalog.Set(
            "更新检查返回了无法识别的状态：{1}",
                "Kiểm tra cập nhật trả về trạng thái không nhận diện được: {1}")
        catalog.Set(
            "最长升级等待（秒）：",
                "Thời gian chờ cập nhật tối đa（giây）:")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），恢复普通重启流程：{3}",
                "Không phát hiện hoạt động cập nhật（{1}, {2} giây）`; tiếp tục quy trình khởi động lại thông thường: {3}")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），目标仍不存在：{3}",
                "Không phát hiện hoạt động cập nhật（{1}, {2} giây）`; đích vẫn không tồn tại: {3}")
        catalog.Set(
            "未找到目标",
                "Không tìm thấy đích")
        catalog.Set(
            "未添加",
                "Chưa thêm")
        catalog.Set(
            "未知升级保护阶段",
                "Giai đoạn bảo vệ khi cập nhật không xác định")
        catalog.Set(
            "未知守护阶段",
                "Giai đoạn giám sát không xác định")
        catalog.Set(
            "未知版本",
                "Phiên bản không xác định")
        catalog.Set(
            "未知解析错误",
                "Lỗi phân tích không xác định")
        catalog.Set(
            "未知错误",
                "Lỗi không xác định")
        catalog.Set(
            "查看实时运行日志`n涵盖监控、重启、升级保护与操作记录",
                "Xem nhật ký hoạt động theo thời gian thực`nGồm bản ghi giám sát, khởi động lại, bảo vệ khi cập nhật và thao tác")
        catalog.Set(
            "查看支持类型、操作方法、守护设置`n以及升级保护说明",
                "Xem loại đích được hỗ trợ, cách thao tác và cài đặt giám sát`nKèm hướng dẫn bảo vệ khi cập nhật")
        catalog.Set(
            "核心守护",
                "Giám sát cốt lõi")
        catalog.Set(
            "核心守护计时器启动失败。",
                "Không thể khởi động bộ hẹn giờ giám sát cốt lõi.")
        catalog.Set(
            "桌面与开始菜单快捷方式",
                "Lối tắt trên màn hình nền và menu Bắt đầu")
        catalog.Set(
            "创建成功！",
                "Đã tạo!")
        catalog.Set(
            "检查小助手更新",
                "Kiểm tra cập nhật trợ lý")
        catalog.Set(
            "检查小助手更新失败：{1}",
                "Không thể kiểm tra cập nhật trợ lý: {1}")
        catalog.Set(
            "检查更新",
                "Kiểm tra cập nhật")
        catalog.Set(
            "检查更新失败：{1}",
                "Kiểm tra cập nhật thất bại: {1}")
        catalog.Set(
            "检查更新超时",
                "Kiểm tra cập nhật hết thời gian")
        catalog.Set(
            "检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。",
                "Phát hiện tác vụ theo lịch trùng tên nhưng tác vụ đó không do chương trình hiện tại tạo. Để tránh xóa nhầm, hãy xử lý nó trong Trình lập lịch tác vụ trước.")
        catalog.Set(
            "检测到安装目录变化",
                "Phát hiện thay đổi thư mục cài đặt")
        catalog.Set(
            "检测到相关安装进程",
                "Phát hiện tiến trình cài đặt liên quan")
        catalog.Set(
            "检测到程序文件变化",
                "Phát hiện thay đổi tệp chương trình")
        catalog.Set(
            "检测到运行中的目标未使用管理员权限：{1}",
                "Phát hiện đích đang chạy không dùng quyền quản trị viên: {1}")
        catalog.Set(
            "检测到进程停止，准备重启：{1}（将在 {2} 秒后启动）",
                "Phát hiện tiến trình dừng`; đang chuẩn bị khởi động lại: {1}（sẽ khởi động sau {2} giây）")
        catalog.Set(
            "正在扫描...",
                "Đang quét...")
        catalog.Set(
            "正在扫描文件夹，可点击取消停止",
                "Đang quét thư mục`; bấm Hủy để dừng")
        catalog.Set(
            "正在扫描：{1}",
                "Đang quét: {1}")
        catalog.Set(
            "正在添加扫描结果...",
                "Đang thêm kết quả quét...")
        catalog.Set(
            "正在添加：{1} / {2}",
                "Đang thêm: {1} / {2}")
        catalog.Set(
            "正常关闭超时后允许强制终止",
                "Cho phép buộc kết thúc sau khi hết thời gian chờ đóng bình thường")
        catalog.Set(
            "正常关闭超时，已强制终止进程 PID：{1}",
                "Đã hết thời gian chờ đóng bình thường`; đã buộc kết thúc tiến trình PID {1}.")
        catalog.Set(
            "正常关闭超时，已按设置跳过强制终止 PID：{1}",
                "Đã hết thời gian chờ đóng bình thường`; đã bỏ qua buộc kết thúc PID {1} theo cài đặt.")
        catalog.Set(
            "没有可安装的应用更新",
                "Không có bản cập nhật ứng dụng có thể cài đặt")
        catalog.Set(
            "浏览",
                "Duyệt")
        catalog.Set(
            "添加扫描结果失败",
                "Không thể thêm kết quả quét")
        catalog.Set(
            "添加守护对象",
                "Thêm mục giám sát")
        catalog.Set(
            "添加守护对象失败，已回滚内存状态：{1}",
                "Không thể thêm mục giám sát`; đã khôi phục trạng thái trong bộ nhớ: {1}")
        catalog.Set(
            "添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放",
                "Thêm ứng dụng, tập lệnh hoặc lối tắt`nHỗ trợ tìm kiếm, nhập hàng loạt thư mục và kéo thả tệp")
        catalog.Set(
            "清除记录",
                "Xóa bản ghi")
        catalog.Set(
            "状态",
                "Trạng thái")
        catalog.Set(
            "独立环境配置 💡`n",
                "Cấu hình môi trường riêng 💡`n")
        catalog.Set(
            "环境变量",
                "Biến môi trường")
        catalog.Set(
            "环境变量（每行一个 KEY=VALUE）：",
                "Biến môi trường（mỗi dòng một KEY=VALUE）:")
        catalog.Set(
            "用户指定",
                "Do người dùng chỉ định")
        catalog.Set(
            "用户结束了升级等待，重新执行安全启动检查：{1}",
                "Người dùng đã kết thúc chờ cập nhật`; đang thực hiện lại kiểm tra khởi động an toàn: {1}")
        catalog.Set(
            "界面语言和字体已即时更新，无需重新启动小助手。",
                "Ngôn ngữ và phông chữ giao diện đã được cập nhật ngay; không cần khởi động lại trợ lý.")
        catalog.Set(
            "更新配置注释语言失败：{1}",
                "Không thể cập nhật ngôn ngữ chú thích trong tệp cấu hình: {1}")
        catalog.Set(
            "；恢复配置失败：{1}",
                "; đồng thời không thể khôi phục cấu hình: {1}")
        catalog.Set(
            "界面显示设置无法即时应用，已恢复原语言和字体：{1}",
                "Không thể áp dụng ngay cài đặt hiển thị. Ngôn ngữ và phông chữ trước đó đã được khôi phục: {1}")
        catalog.Set(
            "无法即时切换界面语言或字体，原显示设置已恢复。`n`n{1}",
                "Không thể đổi ngay ngôn ngữ hoặc phông chữ giao diện. Cài đặt hiển thị trước đó đã được khôi phục.`n`n{1}")
        catalog.Set(
            "显示设置应用失败",
                "Không thể áp dụng cài đặt hiển thị")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Theo phông chữ mặc định của ngôn ngữ（{1}）")
        catalog.Set(
            "正在检查更新…",
                "Đang kiểm tra bản cập nhật…")
        catalog.Set(
            "`; UiFont：界面字体；auto 表示使用当前语言的默认字体，也可填写本机已安装字体名称。",
                "`; UiFont: phông chữ giao diện. auto dùng phông chữ mặc định của ngôn ngữ hiện tại`; cũng có thể nhập tên phông chữ đã cài trên máy.")
        catalog.Set(
            "界面语言：",
                "Ngôn ngữ giao diện:")
        catalog.Set(
            "界面资源",
                "Tài nguyên giao diện")
        catalog.Set(
            "监控与启动",
                "Giám sát và khởi động")
        catalog.Set(
            "守护对象重复",
                "Đích giám sát bị trùng")
        catalog.Set(
            "监控配置加载异常",
                "Lỗi nạp cấu hình giám sát")
        catalog.Set(
            "监控配置加载异常：共 {1} 条记录未能载入。",
                "Lỗi nạp cấu hình giám sát: không thể nạp {1} bản ghi.")
        catalog.Set(
            "监控配置尚未保存，请查看运行日志。",
                "Cấu hình giám sát chưa được lưu. Hãy xem nhật ký hoạt động.")
        catalog.Set(
            "守护对象保存状态无效",
                "Trạng thái lưu mục giám sát không hợp lệ")
        catalog.Set(
            "守护对象注册回调无效",
                "Hàm gọi lại đăng ký mục giám sát không hợp lệ")
        catalog.Set(
            "守护对象路径无效：{1}",
                "Đường dẫn mục giám sát không hợp lệ: {1}")
        catalog.Set(
            "监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核：{1}",
                "Tệp đích không còn tồn tại. Giám sát đã chuyển sang trạng thái thiếu tệp và sẽ tự kiểm tra lại khi tệp xuất hiện: {1}")
        catalog.Set(
            "目标任务需要 WatchdogScheduler",
                "Tác vụ đích cần WatchdogScheduler")
        catalog.Set(
            "目标文件已恢复，重新核对运行状态：{1}",
                "Tệp đích đã xuất hiện trở lại`; đang kiểm tra lại trạng thái chạy: {1}")
        catalog.Set(
            "目标文件缺失时检测到升级活动",
                "Phát hiện hoạt động cập nhật khi tệp đích bị thiếu")
        catalog.Set(
            "目标程序文件不存在",
                "Tệp chương trình đích không tồn tại")
        catalog.Set(
            "目标程序：{1}",
                "Ứng dụng đích: {1}")
        catalog.Set(
            "目标路径",
                "Đường dẫn đích")
        catalog.Set(
            "目标退出时检测到升级信号",
                "Phát hiện tín hiệu cập nhật khi đích thoát")
        catalog.Set(
            "真实目标来源标记",
                "Dấu nguồn của đích thực")
        catalog.Set(
            "真实进程路径无效",
                "Đường dẫn tiến trình thực không hợp lệ")
        catalog.Set(
            "确 定",
                "Xác nhận")
        catalog.Set(
            "程序文件刚刚发生变化",
                "Tệp chương trình vừa thay đổi")
        catalog.Set(
            "程序文件尚未达到稳定等待时间",
                "Tệp chương trình chưa đạt thời gian chờ ổn định")
        catalog.Set(
            "程序文件正在写入或结构不完整",
                "Tệp chương trình đang được ghi hoặc có cấu trúc chưa hoàn chỉnh")
        catalog.Set(
            "稍后",
                "Để sau")
        catalog.Set(
            "窗口层级平台适配器无效",
                "Bộ điều hợp nền tảng phân cấp cửa sổ không hợp lệ")
        catalog.Set(
            "窗口层级管理器无效",
                "Trình quản lý phân cấp cửa sổ không hợp lệ")
        catalog.Set(
            "窗口布局字段不是整数：{1}",
                "Trường bố cục cửa sổ không phải số nguyên: {1}")
        catalog.Set(
            "窗口布局字段超出范围：{1}",
                "Trường bố cục cửa sổ vượt ngoài phạm vi: {1}")
        catalog.Set(
            "窗口布局对象无效",
                "Đối tượng bố cục cửa sổ không hợp lệ")
        catalog.Set(
            "立即更新",
                "Cập nhật ngay")
        catalog.Set(
            "等待 {1} 秒后进行第 {2} 次尝试...",
                "Đợi {1} giây rồi thử lần thứ {2}...")
        catalog.Set(
            "管理员运行状态",
                "Trạng thái chạy với quyền quản trị viên")
        catalog.Set(
            "系统 PowerShell 不可用",
                "PowerShell của hệ thống không khả dụng")
        catalog.Set(
            "系统压缩工具未能创建诊断包",
                "Công cụ nén của hệ thống không tạo được gói chẩn đoán")
        catalog.Set(
            "系统权限拦截",
                "Bị quyền hệ thống chặn")
        catalog.Set(
            "通用",
                "Chung")
        catalog.Set(
            "结束升级等待并恢复守护",
                "Kết thúc chờ cập nhật và tiếp tục giám sát")
        catalog.Set(
            "编码损坏",
                "Mã hóa bị hỏng")
        catalog.Set(
            "缺少窗口布局字段：{1}",
                "Thiếu trường bố cục cửa sổ: {1}")
        catalog.Set(
            "缺少窗口生命周期回调：{1}",
                "Thiếu hàm gọi lại vòng đời cửa sổ: {1}")
        catalog.Set(
            "缺少诊断信息提供器：{1}",
                "Thiếu trình cung cấp thông tin chẩn đoán: {1}")
        catalog.Set(
            "缺少运行参数：{1}",
                "Thiếu tham số chạy: {1}")
        catalog.Set(
            "自动",
                "Tự động")
        catalog.Set(
            "自动识别升级并保护启动过程",
                "Tự động nhận diện cập nhật và bảo vệ quá trình khởi động")
        catalog.Set(
            "自动识别进程",
                "Tự động nhận diện tiến trình")
        catalog.Set(
            "自定义名称",
                "Tên tùy chỉnh")
        catalog.Set(
            "自定义图标",
                "Biểu tượng tùy chỉnh")
        catalog.Set(
            "计划任务冲突",
                "Xung đột tác vụ theo lịch")
        catalog.Set(
            "计划任务操作失败：{1}",
                "Thao tác tác vụ theo lịch thất bại: {1}")
        catalog.Set(
            "设置已更新：轮询={1}ms，序列=[{2}]，日志上限={3}",
                "Đã cập nhật cài đặt: thăm dò={1}ms, chuỗi=[{2}], giới hạn nhật ký={3}")
        catalog.Set(
            "设置无效",
                "Cài đặt không hợp lệ")
        catalog.Set(
            "诊断临时目录已存在",
                "Thư mục tạm chẩn đoán đã tồn tại")
        catalog.Set(
            "诊断包保存目录不存在",
                "Thư mục lưu gói chẩn đoán không tồn tại")
        catalog.Set(
            "诊断包已导出到：`n{1}",
                "Đã xuất gói chẩn đoán tới:`n{1}")
        catalog.Set(
            "诊断包目标文件名已被占用",
                "Tên tệp đích của gói chẩn đoán đã được sử dụng")
        catalog.Set(
            "诊断压缩包未生成",
                "Gói nén chẩn đoán chưa được tạo")
        catalog.Set(
            "该文件不是受支持的图标或图片格式。`n`n支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。",
                "Tệp này không thuộc định dạng biểu tượng hoặc hình ảnh được hỗ trợ.`n`nHỗ trợ ICO, EXE, DLL, CPL, LNK, PNG, JPG, JPEG, JPE, JFIF, BMP, GIF, TIF, TIFF, WebP, SVG và ANI.")
        catalog.Set(
            "该目标已存在、无效或指向目录。",
                "Đích này đã tồn tại, không hợp lệ hoặc trỏ tới một thư mục.")
        catalog.Set(
            "该真实进程已由其他守护对象守护。",
                "Tiến trình thực này đã được một mục giám sát khác bảo vệ.")
        catalog.Set(
            "该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再结束运行。",
                "Phần mềm này đang được bảo vệ khi cập nhật. Hãy đợi cập nhật hoàn tất hoặc kết thúc chờ trong “Bảo vệ khi cập nhật” rồi mới kết thúc tiến trình.")
        catalog.Set(
            "语义版本无效",
                "Phiên bản ngữ nghĩa không hợp lệ")
        catalog.Set(
            "请通过上方按钮搜索或选择，或在下方填写进程名或目标路径：`n【支持程序、脚本、快捷方式，以及文件夹批量导入】",
                "Tìm kiếm hoặc chọn bằng các nút phía trên.`nHoặc nhập tên tiến trình hay đường dẫn đích ở bên dưới.`n【Hỗ trợ chương trình, tập lệnh, lối tắt và nhập thư mục hàng loạt】")
        catalog.Set(
            "请选择现有且可执行的真实程序或脚本路径。",
                "Hãy chọn đường dẫn có thật và có thể thực thi của chương trình hoặc tập lệnh đích.")
        catalog.Set(
            "请选择现有的图标、程序、资源库或快捷方式文件。",
                "Hãy chọn tệp biểu tượng, chương trình, thư viện tài nguyên hoặc lối tắt có sẵn.")
        catalog.Set(
            "读取后台扫描结果失败",
                "Không đọc được kết quả quét nền")
        catalog.Set(
            "调度器已停止",
                "Bộ lập lịch đã dừng")
        catalog.Set(
            "跟随系统",
                "Theo hệ thống")
        catalog.Set(
            "路径",
                "Đường dẫn")
        catalog.Set(
            "轮询间隔必须为 500-86400000 毫秒的正整数！",
                "Khoảng thăm dò phải là số nguyên dương từ 500 đến 86400000 mili giây!")
        catalog.Set(
            "软件升级保护",
                "Bảo vệ khi cập nhật phần mềm")
        catalog.Set(
            "软件升级保护超过最长等待时间，需要用户确认后恢复：{1}",
                "Bảo vệ khi cập nhật phần mềm đã vượt quá thời gian chờ tối đa`; cần người dùng xác nhận trước khi tiếp tục: {1}")
        catalog.Set(
            "软件升级完成，准备恢复启动：{1}",
                "Cập nhật phần mềm đã hoàn tất`; chuẩn bị khởi động lại: {1}")
        catalog.Set(
            "软件升级完成，已恢复正常守护：{1}",
                "Cập nhật phần mềm đã hoàn tất`; đã tiếp tục giám sát bình thường: {1}")
        catalog.Set(
            "载入中...",
                "Đang tải...")
        catalog.Set(
            "运行参数不是支持的界面语言：{1}",
                "Tham số chạy không phải ngôn ngữ giao diện được hỗ trợ: {1}")
        catalog.Set(
            "运行参数不是整数：{1}",
                "Tham số chạy không phải số nguyên: {1}")
        catalog.Set(
            "运行参数不能为空：{1}",
                "Tham số chạy không được để trống: {1}")
        catalog.Set(
            "运行参数对象无效",
                "Đối tượng tham số chạy không hợp lệ")
        catalog.Set(
            "运行参数超出范围：{1}",
                "Tham số chạy vượt ngoài phạm vi: {1}")
        catalog.Set(
            "运行日志",
                "Nhật ký hoạt động")
        catalog.Set(
            "进程仍在运行，忽略重复启动：{1}",
                "Tiến trình vẫn đang chạy`; bỏ qua yêu cầu khởi động trùng lặp: {1}")
        catalog.Set(
            "进程启动后迅速退出或未成功常驻后台",
                "Tiến trình thoát ngay sau khi khởi động hoặc không chạy nền thành công")
        catalog.Set(
            "进程守护小助手",
                "Trợ lý giám sát tiến trình")
        catalog.Set(
            "持续守护重要程序与自动化任务，让日常工作稳定运行",
                "Giữ các ứng dụng và tác vụ tự động thiết yếu luôn hoạt động ổn định")
        catalog.Set(
            "进程守护小助手 - 开机自启守护程序",
                "Trợ lý giám sát tiến trình - Trình giám sát tự khởi động cùng Windows")
        catalog.Set(
            "进程守护小助手已静默启动。",
                "Trợ lý giám sát tiến trình đã khởi động ở chế độ im lặng.")
        catalog.Set(
            "退出检测窗口（秒）：",
                "Khoảng thời gian phát hiện thoát（giây）：")
        catalog.Set(
            "退出清理异常（{1}）：{2}",
                "Lỗi khi dọn dẹp lúc thoát（{1}）: {2}")
        catalog.Set(
            "退出程序",
                "Thoát chương trình")
        catalog.Set(
            "选择主窗口图标",
                "Chọn biểu tượng cửa sổ chính")
        catalog.Set(
            "选择工作目录",
                "Chọn thư mục làm việc")
        catalog.Set(
            "选择快捷方式对应的真实进程",
                "Chọn tiến trình thực tương ứng với lối tắt")
        catalog.Set(
            "选择批处理日志目录",
                "Chọn thư mục nhật ký xử lý hàng loạt")
        catalog.Set(
            "选择文件",
                "Chọn tệp")
        catalog.Set(
            "选择文件夹",
                "Chọn thư mục")
        catalog.Set(
            "选择要监控的文件",
                "Chọn tệp cần giám sát")
        catalog.Set(
            "选择要监控的文件夹",
                "Chọn thư mục cần giám sát")
        catalog.Set(
            "选择诊断包保存位置",
                "Chọn vị trí lưu gói chẩn đoán")
        catalog.Set(
            "选择软件安装目录",
                "Chọn thư mục cài đặt phần mềm")
        catalog.Set(
            "通过拖拽添加了 {1} 个守护对象。",
                "Đã thêm {1} mục giám sát bằng cách kéo thả.")
        catalog.Set(
            "配置仓储无效",
                "Kho cấu hình không hợp lệ")
        catalog.Set(
            "配置写入器无效",
                "Trình ghi cấu hình không hợp lệ")
        catalog.Set(
            "配置文件写入事务正在进行",
                "Giao dịch ghi tệp cấu hình đang được thực hiện")
        catalog.Set(
            "配置通用、监控与启动、停止`n以及日志选项",
                "Cấu hình Chung, Giám sát và khởi động, Dừng`ncùng các tùy chọn Nhật ký")
        catalog.Set(
            "重新加载",
                "Tải lại")
        catalog.Set(
            "重新加载失败",
                "Tải lại thất bại")
        catalog.Set(
            "重新加载失败，已保留当前实例：{1}",
                "Tải lại thất bại`; phiên bản hiện tại vẫn được giữ lại: {1}")
        catalog.Set(
            "重新加载失败，当前守护仍在运行。`n`n{1}",
                "Tải lại thất bại`; chức năng giám sát hiện tại vẫn đang chạy.`n`n{1}")
        catalog.Set(
            "重试序列不能为空！",
                "Chuỗi thử lại không được để trống!")
        catalog.Set(
            "重试序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "Định dạng chuỗi thử lại không đúng! Phải là các số nguyên dương phân cách bằng dấu phẩy（ví dụ: 1,10,60）, mỗi giá trị trong khoảng 1-86400 giây.")
        catalog.Set(
            "重试延迟序列不能为空",
                "Chuỗi độ trễ thử lại không được để trống")
        catalog.Set(
            "重试延迟序列无效",
                "Chuỗi độ trễ thử lại không hợp lệ")
        catalog.Set(
            "错误",
                "Lỗi")
        catalog.Set(
            "名称：{1}`n真实路径：{2}",
                "Tên: {1}`nĐường dẫn thực: {2}")
        catalog.Set(
            "🌿 环境变量：{1} 项`n",
                "🌿 Biến môi trường: {1} mục`n")
        catalog.Set(
            "🎨 自定义名称和图标",
                "🎨 Tên và biểu tượng tùy chỉnh")
        catalog.Set(
            "📁 工作目录：{1}`n",
                "📁 Thư mục làm việc: {1}`n")
        catalog.Set(
            "📂 打开所在位置",
                "📂 Mở vị trí tệp")
        catalog.Set(
            "📂 浏览文件夹...",
                "📂 Duyệt thư mục...")
        catalog.Set(
            "选择...",
                "Chọn...")
        catalog.Set(
            "📄 查看运行日志",
                "📄 Xem nhật ký hoạt động")
        catalog.Set(
            "📄 浏览文件...",
                "📄 Duyệt tệp...")
        catalog.Set(
            "🔄 反转状态",
                "🔄 Đảo trạng thái")
        catalog.Set(
            "🔄 恢复升级保护状态",
                "🔄 Khôi phục trạng thái bảo vệ khi cập nhật")
        catalog.Set(
            "🔄 显式升级维护中",
                "🔄 Đang bảo trì cập nhật tường minh")
        catalog.Set(
            "🔄 检查",
                "🔄 Kiểm tra")
        catalog.Set(
            "🔄 等待程序文件可用",
                "🔄 Đợi tệp chương trình dùng được")
        catalog.Set(
            "🔄 等待程序文件恢复",
                "🔄 Đợi tệp chương trình được khôi phục")
        catalog.Set(
            "🔄 软件升级中",
                "🔄 Phần mềm đang cập nhật")
        catalog.Set(
            "🔄 软件升级保护",
                "🔄 Bảo vệ khi cập nhật phần mềm")
        catalog.Set(
            "⏹️ 结束运行",
                "⏹️ Kết thúc tiến trình")
        catalog.Set(
            "搜索...",
                "Tìm kiếm...")
        catalog.Set(
            "搜索：",
                "Tìm kiếm：")
        catalog.Set(
            "扩展名",
                "Phần mở rộng")
        catalog.Set(
            "🗑️ 删除",
                "🗑️ Xóa")
        catalog.Set(
            "🚀 正在启动...",
                "🚀 Đang khởi động...")
        catalog.Set(
            "🛡️ 以管理员身份运行",
                "🛡️ Chạy với quyền quản trị viên")
        catalog.Set(
            "（{1}）",
                "（{1}）")
        catalog.Set(
            "（第 {1} 行）",
                "（dòng {1}）")
        catalog.Set(
            "（管理员权限）",
                "（quyền quản trị viên）")
        catalog.Set(
            "：{1}",
                "：{1}")
        catalog.Set(
            "Everything 搜索不可用，请确认 Everything 正在运行。",
                "Không thể sử dụng tìm kiếm Everything. Hãy bảo đảm Everything đang chạy.")
        catalog.Set(
            "正在载入 Everything 搜索结果：{1}／{2}",
                "Đang tải kết quả tìm kiếm Everything: {1}/{2}")
        catalog.Set(
            "Everything 搜索结果：{1} 项",
                "Kết quả tìm kiếm Everything: {1} mục")
        catalog.Set(
            "{1}（EXE 版）",
                "{1}（bản EXE）")
        catalog.Set(
            "{1}（源码版）",
                "{1}（bản mã nguồn）")
        catalog.Set(
            "• “结束运行”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。",
                "• “Kết thúc tiến trình” trước tiên sẽ yêu cầu ứng dụng đích thoát bình thường. Khi hết thời gian chờ, tùy chọn trong “Chính sách dừng” sẽ quyết định có buộc ứng dụng kết thúc hay không.")
        catalog.Set(
            "• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。",
                "• Giới thiệu: xem phiên bản ứng dụng và môi trường chạy AutoHotkey, kiểm tra cập nhật thủ công hoặc mở dự án mã nguồn mở.")
        catalog.Set(
            "• 监控与启动：设置进程状态检查间隔、崩溃自动重启延迟序列，以及导入文件夹时是否包含子目录。",
                "• Theo dõi và khởi chạy: đặt khoảng kiểm tra trạng thái tiến trình, chuỗi trì hoãn tự động khởi động lại sau sự cố và việc có bao gồm thư mục con khi nhập thư mục hay không.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。",
                "• Khi phát hiện ứng dụng đích đã dừng, trợ lý sẽ xác nhận lại trạng thái rồi thử theo “Chuỗi trì hoãn tự động khởi động lại sau sự cố”. Nếu liên tiếp thất bại, các mức trì hoãn tiếp theo sẽ được dùng để tránh khởi động lại quá dày.")
        catalog.Set(
            "• 界面语言和内容字体保存后会立即更新主窗口、菜单和托盘，无需重新启动。",
                "• Sau khi lưu ngôn ngữ giao diện hoặc phông chữ nội dung, cửa sổ chính, menu và khay hệ thống sẽ cập nhật ngay mà không cần khởi động lại.")
        catalog.Set(
            "• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。",
                "• Nhật ký: đặt giới hạn hiển thị nhật ký hoạt động, đường dẫn lưu và số ngày giữ nhật ký đầu ra lô, cùng cách dọn dẹp khi khởi động.")
        catalog.Set(
            "• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。",
                "• Chính sách dừng: đặt thời gian chờ đóng ứng dụng GUI và CLI, đồng thời chọn có cho phép buộc kết thúc sau khi đóng bình thường bị quá hạn hay không.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时是否显示主窗口，以及界面语言和内容字体。",
                "• Chung: tạo lối tắt trên màn hình nền và menu Bắt đầu, bật hoặc tắt tác vụ tự khởi động, chọn có hiển thị cửa sổ chính khi khởi động hay không, đồng thời đặt ngôn ngữ giao diện và phông chữ nội dung.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“关于”页会分别显示当前小助手版本、运行形态和实际运行时版本。",
                "• Phiên bản trợ lý và phiên bản AutoHotkey độc lập với nhau. Trang “Giới thiệu” hiển thị riêng phiên bản trợ lý hiện tại, dạng phân phối và phiên bản môi trường chạy thực tế.")
        catalog.Set(
            "CLI 程序关闭超时（秒）：",
                "Thời gian chờ đóng ứng dụng CLI（giây）:")
        catalog.Set(
            "GUI 程序关闭超时（秒）：",
                "Thời gian chờ đóng ứng dụng GUI（giây）:")
        catalog.Set(
            "崩溃自动重启延迟序列（秒）：",
                "Chuỗi trì hoãn tự động khởi động lại sau sự cố（giây）:")
        catalog.Set(
            "崩溃自动重启延迟序列不能为空！",
                "Chuỗi trì hoãn tự động khởi động lại sau sự cố không được để trống!")
        catalog.Set(
            "崩溃自动重启延迟序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "Chuỗi trì hoãn tự động khởi động lại sau sự cố không đúng định dạng! Hãy nhập các số nguyên dương cách nhau bằng dấu phẩy（ví dụ: 1,10,60）, mỗi giá trị từ 1 đến 86400 giây.")
        catalog.Set(
            "当前版本：",
                "Phiên bản hiện tại:")
        catalog.Set(
            "导入文件夹时包含子目录",
                "Bao gồm thư mục con khi nhập thư mục")
        catalog.Set(
            "开源地址",
                "Dự án mã nguồn mở")
        catalog.Set(
            "关于",
                "Giới thiệu")
        catalog.Set(
            "界面内容字体：",
                "Phông chữ nội dung giao diện:")
        catalog.Set(
            "进程状态检查间隔（毫秒）：",
                "Khoảng kiểm tra trạng thái tiến trình（mili giây）:")
        catalog.Set(
            "进程状态检查间隔必须为 500-86400000 毫秒的正整数！",
                "Khoảng kiểm tra trạng thái tiến trình phải là số nguyên dương từ 500 đến 86400000 mili giây!")
        catalog.Set(
            "扩展设置包含无效数值。`n`nGUI 程序关闭超时：1-300 秒`nCLI 程序关闭超时：1-60 秒`n运行日志显示上限：50-10000 条`n批处理日志保留天数：1-3650 天",
                "Cài đặt nâng cao có giá trị không hợp lệ.`n`nThời gian chờ đóng ứng dụng GUI: 1-300 giây`nThời gian chờ đóng ứng dụng CLI: 1-60 giây`nGiới hạn hiển thị nhật ký hoạt động: 50-10000 mục`nSố ngày giữ nhật ký đầu ra lô: 1-3650 ngày")
        catalog.Set(
            "配置通用、监控与启动、停止策略与日志",
                "Cấu hình Chung, Giám sát và khởi động, Chính sách dừng và Nhật ký")
        catalog.Set(
            "批处理日志保存路径：",
                "Đường dẫn lưu nhật ký đầu ra lô:")
        catalog.Set(
            "批处理日志保留天数：",
                "Số ngày giữ nhật ký đầu ra lô:")
        catalog.Set(
            "启动时显示主窗口",
                "Hiển thị cửa sổ chính khi khởi động")
        catalog.Set(
            "设置已更新：进程检查间隔={1}ms，重启延迟序列=[{2}]，日志显示上限={3}",
                "Đã cập nhật cài đặt: khoảng kiểm tra tiến trình={1} ms, chuỗi trì hoãn khởi động lại=[{2}], giới hạn hiển thị nhật ký={3}")
        catalog.Set(
            "停止策略",
                "Chính sách dừng")
        catalog.Set(
            "运行环境：",
                "Môi trường chạy:")
        catalog.Set(
            "运行日志显示上限（条）：",
                "Giới hạn hiển thị nhật ký hoạt động（mục）:")
        catalog.Set("; Theme：界面主题；auto 表示跟随 Windows 系统，light 表示浅色，dark 表示深色。", "; Theme: chủ đề giao diện`; auto theo thiết lập Windows, light dùng giao diện sáng và dark dùng giao diện tối.")
        catalog.Set("主题：", "Chủ đề:")
        catalog.Set("浅色", "Sáng")
        catalog.Set("深色", "Tối")
        catalog.Set("运行参数不是支持的界面主题：{1}", "Thiết lập chạy không phải là chủ đề giao diện được hỗ trợ: {1}")
        catalog.Set("界面显示设置无法即时应用，已恢复原语言、字体和主题：{1}", "Không thể áp dụng ngay thiết lập hiển thị; ngôn ngữ, phông chữ và chủ đề trước đó đã được khôi phục: {1}")
        catalog.Set("无法即时切换界面语言、字体或主题，原显示设置已恢复。`n`n{1}", "Không thể đổi ngay ngôn ngữ, phông chữ hoặc chủ đề giao diện. Thiết lập hiển thị trước đó đã được khôi phục.`n`n{1}")
        catalog.Set("界面语言、字体和主题已即时更新，无需重新启动小助手。", "Ngôn ngữ, phông chữ và chủ đề giao diện đã được cập nhật ngay; không cần khởi động lại trợ lý.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。", "• Chung: tạo lối tắt trên màn hình nền và menu Bắt đầu, bật hoặc tắt tự khởi động bằng tác vụ đã lên lịch, chọn hiển thị cửa sổ chính và kiểm tra cập nhật khi khởi động, đồng thời đặt ngôn ngữ, phông chữ nội dung và chủ đề giao diện.")
        catalog.Set("• 界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Sau khi lưu ngôn ngữ, phông chữ nội dung hoặc chủ đề giao diện, cửa sổ chính, menu và khay hệ thống sẽ cập nhật ngay mà không cần khởi động lại.")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Mở Trợ giúp`nChọn hướng dẫn sử dụng, nhật ký chạy hoặc gửi phản hồi")
        catalog.Set("快揭不开锅了（≥Д≤）", "Sắp cạn kinh phí rồi（≥Д≤）")
        catalog.Set("帮助", "Trợ giúp")
        catalog.Set("提交反馈", "Gửi phản hồi")
        catalog.Set("支持开源项目", "Ủng hộ dự án mã nguồn mở")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式：", "Nếu trợ lý đã giúp bạn tiết kiệm thời gian tìm nguyên nhân sự cố và khôi phục chương trình, hãy ủng hộ tác giả qua mã QR bên dưới!`nVui lòng chọn cách ủng hộ:")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Không tìm thấy ảnh mã QR")
        catalog.Set("• 主界面的“帮助”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。", "• Mục Trợ giúp trên cửa sổ chính mở hướng dẫn sử dụng, nhật ký của phiên hiện tại hoặc trang phản hồi của dự án. Nhật ký ghi lại việc giám sát, khởi động lại, bảo vệ cập nhật và thao tác của người dùng, đồng thời tự động cập nhật.")
        catalog.Set("⚙️ 进程识别与启动设置", "⚙️ Nhận diện tiến trình và thiết lập khởi chạy")
        catalog.Set("进程识别与启动设置", "Nhận diện tiến trình và thiết lập khởi chạy")
        catalog.Set("进程识别", "Nhận diện tiến trình")
        catalog.Set("启动环境", "Môi trường khởi chạy")
        catalog.Set("快捷方式仍用于启动；真实进程用于判断程序是否正在运行。", "Lối tắt vẫn được dùng để khởi chạy; tiến trình thực tế được dùng để xác định ứng dụng có đang chạy hay không.")
        catalog.Set("该守护对象直接启动并监控同一个目标，无需额外识别真实进程。", "Mục này trực tiếp khởi chạy và giám sát cùng một đích nên không cần nhận diện riêng tiến trình thực tế.")
        catalog.Set("用于判断运行状态的真实进程：", "Tiến trình thực tế dùng để xác định trạng thái:")
        catalog.Set("用于判断运行状态的目标：", "Đích dùng để xác định trạng thái:")
        catalog.Set("重新识别", "Nhận diện lại")
        catalog.Set("选择程序", "Chọn chương trình")
        catalog.Set("识别依据：{1}", "Nguồn nhận diện: {1}")
        catalog.Set("识别依据：暂无可靠结果", "Nguồn nhận diện: chưa có kết quả đáng tin cậy")
        catalog.Set("识别状态：路径有效。", "Trạng thái nhận diện: đường dẫn hợp lệ.")
        catalog.Set("识别状态：路径暂时不可用，已保留上次可靠结果。", "Trạng thái nhận diện: đường dẫn tạm thời không khả dụng; kết quả đáng tin cậy gần nhất đã được giữ lại.")
        catalog.Set("识别状态：路径暂时不可用，将保留此身份等待恢复。", "Trạng thái nhận diện: đường dẫn tạm thời không khả dụng; danh tính này sẽ được giữ lại trong khi chờ khôi phục.")
        catalog.Set("识别状态：未找到可靠目标，请改为手动指定。", "Trạng thái nhận diện: không tìm thấy đích đáng tin cậy. Hãy chỉ định thủ công.")
        catalog.Set("识别状态：手动指定，保存时将验证路径。", "Trạng thái nhận diện: đã chỉ định thủ công; đường dẫn sẽ được kiểm tra khi lưu.")
        catalog.Set("识别状态：启动入口与监控目标一致。", "Trạng thái nhận diện: điểm khởi chạy và đích giám sát là một.")
        catalog.Set("这些设置仅在小助手下次启动目标时生效，不会重启当前进程。", "Các thiết lập này chỉ có hiệu lực vào lần tới trợ lý khởi chạy đích và không khởi động lại tiến trình hiện đang chạy.")
        catalog.Set("留空时使用快捷方式工作目录或程序所在目录。", "Để trống để dùng thư mục làm việc của lối tắt hoặc thư mục chứa chương trình.")
        catalog.Set("留空时不附加额外参数。", "Để trống nếu không cần thêm đối số.")
        catalog.Set("留空时继承小助手当前环境。", "Để trống để kế thừa môi trường hiện tại của trợ lý.")
        catalog.Set("工作目录不存在或不可访问：{1}", "Thư mục làm việc không tồn tại hoặc không thể truy cập: {1}")
        catalog.Set("工作目录无效", "Thư mục làm việc không hợp lệ")
        catalog.Set("环境变量第 {1} 行缺少等号（KEY=VALUE）。", "Dòng biến môi trường {1} thiếu dấu bằng（KEY=VALUE）.")
        catalog.Set("环境变量第 {1} 行的名称无效：{2}", "Dòng biến môi trường {1} có tên không hợp lệ: {2}")
        catalog.Set("环境变量第 {1} 行重复定义了 {2}。", "Dòng biến môi trường {1} định nghĩa trùng {2}.")
        catalog.Set("环境变量配置无法解析。", "Không thể phân tích cấu hình biến môi trường.")
        catalog.Set("环境变量配置无效", "Biến môi trường không hợp lệ")
        catalog.Set("设置已应用到当前运行，但暂未写入配置文件；小助手将在后台自动重试。", "Thiết lập đã có hiệu lực trong phiên hiện tại nhưng chưa được ghi vào tệp cấu hình. Trợ lý sẽ tự động thử lại trong nền.")
        catalog.Set("配置暂未写入", "Cấu hình chưa được ghi")
        catalog.Set("已更新进程识别与启动设置：{1}", "Đã cập nhật nhận diện tiến trình và thiết lập khởi chạy: {1}")
        catalog.Set("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。", "• Lối tắt: LNK, URL và APPREF-MS, bao gồm lối tắt MSI có thể xác định đích thực tế. Với lối tắt đặc biệt, hãy chỉ định thủ công tiến trình thực tế trong mục Nhận diện tiến trình và thiết lập khởi chạy.")
        catalog.Set("• 右键守护对象可自定义主窗口名称和图标，也可打开所在位置、结束运行、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。“结束运行”会同时暂停守护，目标不会被自动重新启动；要求管理员运行但当前权限不符时仍会显示警告。", "• Nhấp phải một mục để đổi tên và biểu tượng, mở vị trí tệp, kết thúc tiến trình, sửa đường dẫn và cấu hình nhận diện, khởi chạy, bảo vệ cập nhật. Kết thúc tiến trình cũng tạm dừng giám sát nên mục tiêu không tự khởi động lại; cảnh báo thiếu quyền quản trị vẫn được hiển thị.")
        catalog.Set("添加", "Thêm")
        catalog.Set("暂停", "Tạm dừng")
        catalog.Set("恢复", "Tiếp tục")
        catalog.Set("删除", "Xóa")
        catalog.Set("设置", "Cài đặt")
        catalog.Set("打赏", "Ủng hộ")
        catalog.Set("保存", "Lưu")
        catalog.Set("取消", "Hủy")
        catalog.Set("反转状态", "Đảo trạng thái")
        catalog.Set("统计：运行", "Đang chạy")
        catalog.Set("统计：停止", "Đã dừng")
        catalog.Set("统计：恢复", "Đang phục hồi")
        catalog.Set("统计：升级", "Đang cập nhật")
        catalog.Set("统计：暂停", "Đã tạm dừng")
        catalog.Set("统计：失效", "Đã vô hiệu")
        catalog.Set("统计：总计", "Tổng")
        catalog.Set("配置未保存", "Cấu hình chưa được lưu")
        catalog.Set("创建", "Tạo")
        catalog.Set("开启", "Bật")
        catalog.Set("关闭", "Tắt")
        catalog.Set("切换", "Chuyển đổi")
        catalog.Set("冲突", "Xung đột")
        catalog.Set("浏览", "Duyệt")
        catalog.Set("监控配置", "Cấu hình giám sát")
        catalog.Set("管理员运行状态", "Chạy với quyền quản trị")
        catalog.Set("调整守护顺序", "Sắp xếp lại danh sách giám sát")
        catalog.Set("编辑完整路径", "Chỉnh sửa đường dẫn đầy đủ")
        catalog.Set("自定义名称和图标", "Tùy chỉnh tên và biểu tượng")
        catalog.Set("已撤销：{1}", "Đã hoàn tác: {1}")
        catalog.Set("已重做：{1}", "Đã làm lại: {1}")
        catalog.Set("Everything 搜索暂时不可用，请稍后重试。", "Tìm kiếm bằng Everything hiện tạm thời không khả dụng. Hãy thử lại sau.")
        catalog.Set("Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。", "Thành phần tìm kiếm Everything bị thiếu hoặc không thể nạp. Hãy giải nén đầy đủ hoặc cài đặt lại trợ lý.")
        catalog.Set("已找到 Everything，但无法后台启动，请手动启动后重试。", "Đã tìm thấy Everything nhưng không thể khởi chạy trong nền. Hãy tự mở Everything rồi thử lại.")
        catalog.Set("后台启动 Everything 失败：{1}", "Không thể khởi chạy Everything trong nền: {1}")
        catalog.Set("正在后台启动 Everything 并等待搜索服务就绪...", "Đang khởi chạy Everything trong nền và chờ dịch vụ tìm kiếm sẵn sàng...")
        catalog.Set("已在后台启动 Everything：{1}", "Đã khởi chạy Everything trong nền: {1}")
        catalog.Set("等待 Everything 搜索服务就绪超时：{1}", "Hết thời gian chờ dịch vụ tìm kiếm Everything sẵn sàng: {1}")
        catalog.Set("未找到 Everything，点击前往官网下载最新版：{1}", "Không tìm thấy Everything. Nhấp để tải bản mới nhất từ trang chính thức: {1}")
        catalog.Set("本机未找到 Everything；程序搜索需要 Everything 后台服务。", "Không tìm thấy Everything trên máy này; tính năng tìm chương trình cần dịch vụ Everything chạy trong nền.")
        catalog.Set("• 程序搜索：使用 Everything 服务并显示全部匹配结果；未运行时会尝试在本机查找并后台启动，未找到时提供官网最新版下载地址。", "• Tìm chương trình: sử dụng dịch vụ Everything và hiển thị mọi kết quả phù hợp. Nếu Everything chưa chạy, trợ lý sẽ tìm trên máy và khởi chạy trong nền; nếu không tìm thấy, trợ lý sẽ cung cấp liên kết tải bản mới nhất từ trang chính thức.")
        catalog.Set("• 小助手随包的 Everything64.dll 只是连接 Everything 后台实例的 SDK 客户端，不负责扫描磁盘或建立索引，不能替代 Everything 本体。", "• Everything64.dll đi kèm trợ lý chỉ là ứng dụng khách SDK dùng để kết nối với phiên Everything chạy nền. Tệp này không quét ổ đĩa, không tạo chỉ mục và không thể thay thế ứng dụng Everything.")
        catalog.Set("六、进程识别与启动设置", "6. Nhận diện tiến trình và thiết lập khởi chạy")
        catalog.Set("• 此设置只作用于当前守护对象，并将“用什么启动”和“用什么判断正在运行”分开处理。启动环境只在小助手下次启动目标时生效，不会重启当前进程。", "• Các thiết lập này chỉ áp dụng cho mục đang được giám sát và tách riêng cách khởi chạy khỏi bằng chứng xác định mục đang chạy. Môi trường khởi chạy chỉ có hiệu lực vào lần tới trợ lý chạy đích và không khởi động lại tiến trình hiện tại.")
        catalog.Set("• 直接添加程序或脚本时，启动入口与监控目标相同；EXE 按完整路径识别，脚本按宿主进程命令行中的脚本路径识别。", "• Khi thêm trực tiếp một chương trình hoặc tập lệnh, điểm khởi chạy cũng là đích giám sát. Tệp EXE được nhận diện theo đường dẫn đầy đủ; tập lệnh được nhận diện theo đường dẫn tập lệnh trong dòng lệnh của tiến trình chủ.")
        catalog.Set("• 添加 LNK 快捷方式时，快捷方式始终作为启动入口；自动识别出的真实程序或脚本只用于判断运行状态。", "• Khi thêm lối tắt LNK, lối tắt luôn được giữ làm điểm khởi chạy. Chương trình hoặc tập lệnh thực tế được nhận diện tự động chỉ dùng để xác định trạng thái chạy.")
        catalog.Set("• 自动识别会综合快捷方式目标、参数、Windows Installer 信息、安装目录、文件版本信息和已观察进程；证据不唯一时不会随意绑定。", "• Nhận diện tự động kết hợp đích và đối số của lối tắt, thông tin Windows Installer, thư mục cài đặt, thông tin phiên bản tệp và các tiến trình đã quan sát. Trợ lý sẽ không tùy tiện liên kết khi bằng chứng còn mơ hồ.")
        catalog.Set("• 自动结果不正确时改用“用户指定”，选择程序正常运行期间持续存在的主程序或脚本；不要选择启动器、更新器或短暂子进程。", "• Nếu kết quả tự động không đúng, hãy chọn Chỉ định thủ công rồi chọn chương trình chính hoặc tập lệnh tồn tại suốt thời gian ứng dụng hoạt động bình thường. Không chọn trình khởi chạy, trình cập nhật hay tiến trình con chỉ tồn tại trong chốc lát.")
        catalog.Set("启动程序或解释器：", "Chương trình khởi chạy hoặc trình thông dịch:")
        catalog.Set("留空时按目标类型自动启动；可选择 Python、AutoHotkey、PowerShell、Node.js、Java 等运行时。", "Để trống để tự khởi chạy theo loại đích; cũng có thể chọn môi trường chạy như Python, AutoHotkey, PowerShell, Node.js hoặc Java.")
        catalog.Set("启动程序参数：", "Đối số của chương trình khởi chạy:")
        catalog.Set("参数顺序为：启动程序参数、目标路径、目标参数；例如 Java 使用 -jar。", "Thứ tự là đối số của chương trình khởi chạy, đường dẫn đích rồi đến đối số của đích; chẳng hạn Java dùng -jar.")
        catalog.Set("目标参数（Args）：", "Đối số của đích（Args）:")
        catalog.Set("留空时继承小助手当前环境；值中可用 %变量名% 引用已有环境变量。", "Để trống để kế thừa môi trường hiện tại của trợ lý; có thể dùng %TÊN_BIẾN% trong giá trị để tham chiếu biến môi trường hiện có.")
        catalog.Set("选择启动程序或解释器", "Chọn chương trình khởi chạy hoặc trình thông dịch")
        catalog.Set("可执行程序", "Chương trình thực thi")
        catalog.Set("请先选择启动程序或解释器，再填写它的参数。", "Hãy chọn chương trình khởi chạy hoặc trình thông dịch trước khi nhập đối số của chương trình đó.")
        catalog.Set("启动程序未设置", "Chưa đặt chương trình khởi chạy")
        catalog.Set("启动程序或解释器不存在：{1}", "Chương trình khởi chạy hoặc trình thông dịch không tồn tại: {1}")
        catalog.Set("启动程序无效", "Chương trình khởi chạy không hợp lệ")
        catalog.Set("整条启动配置", "toàn bộ cấu hình khởi chạy")
        catalog.Set("启动程序或解释器", "chương trình khởi chạy hoặc trình thông dịch")
        catalog.Set("解释器参数", "đối số của trình thông dịch")
        catalog.Set("• 直接脚本可指定“启动程序或解释器”，选择实际执行脚本的可执行文件，例如 Python、AutoHotkey、PowerShell、Node.js、Ruby、Perl、PHP、Lua、Java 或 Bash；留空时沿用系统默认启动方式。", "• Với tập lệnh được thêm trực tiếp, mục Chương trình khởi chạy hoặc trình thông dịch cho phép chọn tệp thực thi thật sự chạy tập lệnh, chẳng hạn Python, AutoHotkey, PowerShell, Node.js, Ruby, Perl, PHP, Lua, Java hoặc Bash. Để trống để dùng cách khởi chạy mặc định của hệ thống.")
        catalog.Set("• “启动程序参数”位于目标路径之前，“目标参数（Args）”位于目标路径之后。Java 可填写 -jar；PowerShell 可填写 -NoProfile -ExecutionPolicy Bypass -File。", "• Đối số của chương trình khởi chạy nằm trước đường dẫn đích; Đối số của đích（Args）nằm sau đường dẫn đích. Với Java có thể dùng -jar; với PowerShell có thể dùng -NoProfile -ExecutionPolicy Bypass -File.")
        catalog.Set("• Python 虚拟环境请选择该环境的 Scripts\python.exe；其他语言也可选择项目要求的确切运行时版本。进程识别仍以目标脚本路径为准，不会误把解释器本身当成守护目标。", "• Với môi trường ảo Python, hãy chọn Scripts\python.exe của chính môi trường đó. Các ngôn ngữ khác cũng có thể chọn đúng phiên bản môi trường chạy mà dự án yêu cầu. Tiến trình vẫn được nhận diện theo đường dẫn tập lệnh đích nên trình thông dịch sẽ không bị nhầm là đích giám sát.")
        catalog.Set("• 工作目录（CWD）用于解析相对路径；留空时使用快捷方式工作目录或目标所在目录。", "• Thư mục làm việc（CWD）dùng để phân giải đường dẫn tương đối. Nếu để trống, trợ lý dùng thư mục làm việc của lối tắt hoặc thư mục chứa đích.")
        catalog.Set("• 环境变量每行填写一个 KEY=VALUE，只覆盖列出的变量；值中可用 %变量名% 引用已有环境变量。启动完成后小助手会恢复自身环境。", "• Nhập mỗi biến môi trường trên một dòng theo dạng KEY=VALUE. Chỉ các biến được liệt kê mới bị ghi đè; có thể dùng %TÊN_BIẾN% để tham chiếu giá trị hiện có. Sau khi khởi chạy, trợ lý sẽ khôi phục môi trường của chính mình.")
        catalog.Set("; AppN 与 [Apps] 中同名的守护对象一一对应，依次保存启动程序或解释器路径及其参数。", "; Mỗi AppN tương ứng với đối tượng giám sát cùng tên trong [Apps] và lần lượt lưu đường dẫn của chương trình khởi chạy hoặc trình thông dịch cùng các đối số của nó.")
        catalog.Set("; 两个字段均为 <HEX> 编码；留空时由小助手按目标类型使用默认启动方式。", "; Cả hai trường đều được mã hóa dạng <HEX>; khi để trống, trợ lý dùng cách khởi chạy mặc định cho loại đích.")
        catalog.Set("守护对象不能指向文件夹：{1}", "Mục giám sát không thể trỏ đến thư mục: {1}")
        catalog.Set("自动识别目标新位置", "Tự động nhận diện vị trí mới của đích")
        catalog.Set("检测到的目标新位置已失效，请重新操作。", "Vị trí mới đã phát hiện của đích không còn hợp lệ. Vui lòng thử lại.")
        catalog.Set("已更新已更名的守护目标：{1} -> {2}", "Đã cập nhật đích giám sát được đổi tên: {1} -> {2}")
        catalog.Set("守护目标内容迁移识别服务未能启动。", "Không thể khởi động dịch vụ phát hiện di chuyển nội dung của đích giám sát.")
        catalog.Set("检测到守护目标可能已更名，等待用户确认：{1} -> {2}", "Đích giám sát có thể đã được đổi tên`; đang chờ người dùng xác nhận: {1} -> {2}")
        catalog.Set("确认窗口暂时无法显示，将稍后重试", "Tạm thời không thể hiển thị cửa sổ xác nhận. Sẽ thử lại sau.")
        catalog.Set("发现多个内容完全相同的迁移候选，已暂停自动迁移：{1}", "Đã tìm thấy nhiều ứng viên có nội dung giống hệt nhau`; quá trình di chuyển tự động đã tạm dừng: {1}")
        catalog.Set("检测到内容一致的守护目标新位置，等待用户确认：{1} -> {2}", "Đã phát hiện vị trí mới có nội dung khớp`; đang chờ xác nhận: {1} -> {2}")
        catalog.Set("守护目标内容迁移识别异常：{1}", "Lỗi phát hiện di chuyển nội dung của đích giám sát: {1}")
        catalog.Set("等待确认目标新位置", "Đang chờ xác nhận vị trí mới của đích")
        catalog.Set("确认目标新位置", "Xác nhận vị trí mới của đích")
        catalog.Set("检测到守护目标可能已更名", "Đích giám sát có thể đã được đổi tên")
        catalog.Set("小助手找到了与原文件内容完全一致的新路径。确认后将更新守护目标，名称、图标和启动设置保持不变。", "Trợ lý đã tìm thấy đường dẫn mới có nội dung tệp khớp hoàn toàn với tệp ban đầu. Sau khi xác nhận, đích giám sát sẽ được cập nhật mà vẫn giữ nguyên tên, biểu tượng và thiết lập khởi chạy.")
        catalog.Set("原路径：", "Đường dẫn cũ:")
        catalog.Set("新路径：", "Đường dẫn mới:")
        catalog.Set("识别依据：", "Căn cứ nhận diện: ")
        catalog.Set("更新守护路径", "Cập nhật đường dẫn giám sát")
        catalog.Set("忽略", "Bỏ qua")
        catalog.Set("更新已更名的守护目标", "Cập nhật đích giám sát được đổi tên")
        catalog.Set("• 直接添加的程序或脚本本身或上级目录被更名、跨目录或跨磁盘移动后，小助手会按文件大小筛选并以 SHA-256 内容哈希确认新路径；即使移动发生在小助手关闭期间也能识别。", "• Khi chương trình, tập lệnh hoặc thư mục cha được đổi tên hay di chuyển giữa các thư mục hoặc ổ đĩa, trợ lý lọc theo kích thước và xác nhận đường dẫn mới bằng hàm băm nội dung SHA-256, kể cả khi việc di chuyển xảy ra lúc trợ lý đã đóng.")
        catalog.Set("• 文件名、文件 ID 和目录监听不参与迁移判断。发现多个内容相同的副本或扫描未完整完成时不会猜测目标；确认后只更新守护路径，名称、图标和启动设置保持不变。", "• Tên tệp, ID tệp và trình theo dõi thư mục không tham gia quyết định di chuyển. Trợ lý không suy đoán khi có nhiều bản sao giống nhau hoặc quá trình quét chưa hoàn tất. Xác nhận chỉ cập nhật đường dẫn giám sát và giữ nguyên tên, biểu tượng cùng thiết lập khởi chạy.")
        catalog.Set("; AppN 与 [Apps] 中同名的直接文件目标一一对应，依次保存文件大小和 SHA-256 内容哈希。", "; Mỗi mục AppN tương ứng với tệp được giám sát trực tiếp có cùng tên trong [Apps] và lưu kích thước tệp, sau đó là hàm băm nội dung SHA-256.")
        catalog.Set("; 此节由小助手自动维护，用于在文件或目录改名、跨目录或跨磁盘移动后确认内容未变；请勿手动编辑。", "; Trợ lý tự động duy trì phần này để xác nhận nội dung không đổi sau khi đổi tên hoặc di chuyển tệp hay thư mục giữa các thư mục hoặc ổ đĩa. Không chỉnh sửa thủ công.")
        catalog.Set("Everything64.dll 已加载，但 Everything 后台实例未响应；正在尝试定位并启动 Everything 本体。", "Everything64.dll is loaded, but the Everything background instance is not responding. The assistant is trying to locate and start the Everything application.")
        catalog.Set("Everything 查询失败：{1}", "Everything query failed: {1}")
        catalog.Set("Everything 搜索暂时不可用：后台实例未返回结果，请稍后重试。", "Everything search is temporarily unavailable: the background instance did not return results. Try again shortly.")
        catalog.Set("内存不足", "Not enough memory")
        catalog.Set("后台 IPC 服务不可用", "The background IPC service is unavailable")
        catalog.Set("无法注册 Everything 查询窗口类", "Could not register the Everything query window class")
        catalog.Set("无法创建 Everything 查询窗口", "Could not create the Everything query window")
        catalog.Set("无法创建 Everything 查询线程", "Could not create the Everything query thread")
        catalog.Set("结果索引无效", "The result index is invalid")
        catalog.Set("调用顺序无效", "The call sequence is invalid")
        catalog.Set("未知错误码 {1}", "Unknown error code {1}")
        catalog.Set("已找到 Everything 本体，但无法后台启动；请手动启动 Everything 后重试。", "Everything was found but could not be started in the background. Start Everything manually and try again.")
        catalog.Set("后台启动 Everything 失败：{1}（路径：{2}；发现过程：{3}）", "Failed to start Everything in the background: {1} (path: {2}; discovery: {3})")
        catalog.Set("正在后台启动 Everything 本体并等待搜索服务就绪...", "Starting the Everything application in the background and waiting for the search service...")
        catalog.Set("已启动 Everything，但后台搜索服务仍未响应；请确认 Everything 主程序完成启动且服务可用。", "Everything was started, but the background search service is still not responding. Confirm that Everything finished starting and its service is available.")
        catalog.Set("未找到 Everything 本体，点击前往官网下载最新版：{1}", "Everything was not found. Click to download the latest version from the official site: {1}")
        catalog.Set("本机未找到 Everything 本体；程序搜索需要 Everything 的索引和后台服务，随包 Everything64.dll 只是 IPC 客户端。{1}{2}", "Everything was not found on this computer. Program search requires Everything's index and background service; the bundled Everything64.dll is only an IPC client. {1}{2}")
        catalog.Set("暂时无法核对现有进程，延迟启动以避免重复实例：{1}{2}", "The existing process cannot be verified yet, so startup is delayed to avoid a duplicate instance: {1}{2}")
        catalog.Set("来源：{1}", "Source: {1}")
        catalog.Set("原因：{1}", "Reason: {1}")
        catalog.Set("原因码：{1}", "Reason code: {1}")
        catalog.Set("命令行探测", "command-line probe")
        catalog.Set("进程路径探测", "process-path probe")
        catalog.Set("工作目录探测", "working-directory probe")
        catalog.Set("后台进程快照", "background process snapshot")
        catalog.Set("进程名探测", "process-name probe")
        catalog.Set("AutoHotkey 窗口探测", "AutoHotkey window probe")
        catalog.Set("目标探活配置", "target probe configuration")
        catalog.Set("后台进程快照不可用", "The background process snapshot is unavailable")
        catalog.Set("候选进程命令行不可用", "The candidate process command line is unavailable")
        catalog.Set("命令行只提供相对目标路径，无法可靠匹配", "The command line provides only a relative target path, so it cannot be matched reliably")
        catalog.Set("候选进程镜像路径不可访问", "The candidate process image path is inaccessible")
        catalog.Set("候选进程创建身份无法核对", "The candidate process creation identity cannot be verified")
        catalog.Set("存在多个候选进程，无法唯一确认", "Multiple candidate processes exist, so the target cannot be uniquely confirmed")
        catalog.Set("目标探活规格无效", "The target probe specification is invalid")
        catalog.Set("无法执行内容迁移：缺少旧文件的完整内容指纹：{1}", "Content relocation cannot run because the previous file has no complete content fingerprint: {1}")
        catalog.Set("监测到目标文件缺失，内容迁移将在缺失状态稳定后开始扫描：{1}", "The target file is missing; content relocation will start scanning after the missing state is stable: {1}")
        catalog.Set("内容迁移暂缓：目标正处于升级保护、维护恢复或近期启动信号保护中：{1}", "Content relocation is paused because the target is under update protection, maintenance recovery, or recent launch-signal protection: {1}")
        catalog.Set("内容迁移候选已被拒绝：{1} -> {2}（候选不存在、扩展名不兼容、已被守护或与现有目标冲突）", "The content relocation candidate was rejected: {1} -> {2} (candidate missing, incompatible extension, already monitored, or conflicting with an existing target)")
        catalog.Set("内容迁移候选仍在本次忽略冷却期内：{1} -> {2}", "The content relocation candidate is still in this ignore cooldown: {1} -> {2}")
        catalog.Set("后台扫描失败或超时", "The background scan failed or timed out")
        catalog.Set("扫描未能在时限内完整核对", "The scan could not complete verification within the time limit")
        catalog.Set("内容迁移扫描未完成，将稍后重试：{1}（搜索根：{2}；原因：{3}）", "Content relocation scan did not complete and will retry later: {1} (search root: {2}; reason: {3})")
        catalog.Set("发现多个内容完全相同的迁移候选，已暂停自动迁移：{1}（候选：{2}）", "Multiple relocation candidates with identical content were found; automatic relocation is paused: {1} (candidates: {2})")
        catalog.Set("正在扫描内容迁移候选：{1}（搜索根：{2}；方式：{3}）", "Scanning for content relocation candidates: {1} (search root: {2}; method: {3})")
        catalog.Set("Everything 索引预筛选", "Everything index prefilter")
        catalog.Set("直接递归扫描", "direct recursive scan")
        catalog.Set("无法启动内容迁移扫描，已尝试下一个搜索根：{1}（搜索根：{2}；方式：{3}）", "Could not start the content relocation scan; trying the next search root: {1} (search root: {2}; method: {3})")
        catalog.Set("尚未找到内容完全一致的迁移候选，将稍后重试：{1}（已按扩展名、大小和 SHA-256 完整内容指纹核对）", "No relocation candidate with identical content has been found yet; will retry later: {1} (checked by extension, size, and full SHA-256 content fingerprint)")
        catalog.Set("未知", "Unknown")
        catalog.Set("无", "None")
        catalog.Set("，另有 {1} 个", ", plus {1} more")
        catalog.Set("🔄 重新启动", "🔄 Khởi động lại")
        catalog.Set("点个 star 吧~", "Hãy thắp sáng một ngôi sao nhỏ~")
        catalog.Set("⏳ 停止原进程...", "⏳ Đang dừng tiến trình cũ...")
        catalog.Set("❌ 无法停止原进程", "❌ Không thể dừng tiến trình cũ")
        catalog.Set("手动触发了重新启动：{1}", "Đã yêu cầu khởi động lại thủ công: {1}")
        catalog.Set("手动重启已取消，原进程未能停止：{1}", "Đã hủy khởi động lại thủ công vì không thể dừng tiến trình cũ: {1}")
        catalog.Set("暂时无法查询进程状态，稍后重试手动重启：{1}", "Tạm thời không thể truy vấn trạng thái tiến trình`; sẽ thử lại thao tác khởi động lại thủ công sau: {1}")
        catalog.Set("暂时无法重新启动", "Tạm thời không thể khởi động lại")
        catalog.Set("该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。", "Phần mềm này đang được bảo vệ khi cập nhật. Hãy đợi cập nhật hoàn tất hoặc kết thúc chờ trong “Bảo vệ khi cập nhật” rồi mới khởi động lại.")
        catalog.Set("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• “Khởi động lại” trước tiên sẽ yêu cầu ứng dụng đích thoát bình thường. Khi hết thời gian chờ, tùy chọn trong “Chính sách dừng” sẽ quyết định có buộc ứng dụng kết thúc hay không.")
        catalog.Set("查看版本、运行环境和项目入口", "Xem phiên bản, môi trường chạy và liên kết dự án")
        catalog.Set("找作者对线", "Trao đổi với tác giả")
        return catalog
    }
}
