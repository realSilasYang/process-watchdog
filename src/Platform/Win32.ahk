; 项目使用的 Win32 常量与顶层窗口首次映射入口。
; 数值保持与 Windows SDK 一致；首次映射器只编排 DWM 调用与调用方回调，
; 不持有状态、句柄或内存资源。

class Win32 {
    static DWMWA_CLOAK := 13
    static DWMWA_CLOAKED := 14
    static DWM_CLOAKED_APP := 0x00000001
    static WM_NULL := 0x0000
    static AHK_NOTIFYICON := 0x0404
    static NIN_BALLOONUSERCLICK := 0x0405
    static WM_MOVE := 0x0003
    static WM_CLOSE := 0x0010
    static WM_SETTINGCHANGE := 0x001A
    static WM_THEMECHANGED := 0x031A
    static WM_DRAWITEM := 0x002B
    static WM_MEASUREITEM := 0x002C
    static WM_NCDESTROY := 0x0082
    static WM_SETREDRAW := 0x000B
    static WM_GETFONT := 0x0031
    static WM_SETFOCUS := 0x0007
    static WM_KILLFOCUS := 0x0008
    static WM_CANCELMODE := 0x001F
    static WM_SETICON := 0x0080
    static WM_NCLBUTTONDOWN := 0x00A1
    static WM_KEYDOWN := 0x0100
    static WM_COMMAND := 0x0111
    static WM_SYSCOMMAND := 0x0112
    static WM_SETCURSOR := 0x0020
    static WM_MOUSEMOVE := 0x0200
    static WM_LBUTTONDOWN := 0x0201
    static WM_LBUTTONUP := 0x0202
    static WM_LBUTTONDBLCLK := 0x0203
    static WM_RBUTTONDOWN := 0x0204
    static WM_CAPTURECHANGED := 0x0215
    static WM_MOUSELEAVE := 0x02A3
    static WM_DPICHANGED := 0x02E0
    static WM_DROPFILES := 0x0233
    static WM_COPYGLOBALDATA := 0x0049
    static WM_COPYDATA := 0x004A
    static NM_CUSTOMDRAW := -12
    static CDDS_PREPAINT := 0x00000001
    static CDDS_ITEMPREPAINT := 0x00010001
    static CDDS_ITEMPOSTPAINT := 0x00010002
    static CDRF_DODEFAULT := 0x00000000
    static CDRF_NOTIFYPOSTPAINT := 0x00000010
    static CDRF_NOTIFYITEMDRAW := 0x00000020
    static CDIS_SELECTED := 0x0001
    static CBN_DROPDOWN := 7
    static CBN_CLOSEUP := 8
    static CB_GETDROPPEDCONTROLRECT := 0x0152
    static CB_GETITEMHEIGHT := 0x0154
    static CB_GETTOPINDEX := 0x015B
    static CB_SETTOPINDEX := 0x015C
    static EM_SETSEL := 0x00B1
    static EM_SCROLLCARET := 0x00B7
    static EM_SETMARGINS := 0x00D3
    static EM_GETMARGINS := 0x00D4
    static EM_GETSEL := 0x00B0
    static EM_LINESCROLL := 0x00B6
    static EM_GETFIRSTVISIBLELINE := 0x00CE
    static EM_GETRECT := 0x00B2
    static EM_GETLINECOUNT := 0x00BA
    static EM_CHARFROMPOS := 0x00D7
    static EC_LEFTMARGIN := 0x0001
    static EC_RIGHTMARGIN := 0x0002
    static LVM_GETCOLUMNWIDTH := 0x101D
    static LVM_GETCOLUMNW := 0x105F
    static LVM_GETHEADER := 0x101F
    static LVM_GETIMAGELIST := 0x1002
    static LVM_HITTEST := 0x1012
    static LVM_REDRAWITEMS := 0x1015
    static LVM_SETITEMSTATE := 0x102B
    static LVM_GETITEMSTATE := 0x102C
    static LVM_SETCOLUMNORDERARRAY := 0x103A
    static LVM_GETCOLUMNORDERARRAY := 0x103B
    static LVM_SETITEMW := 0x104C
    static LVIF_STATE := 0x00000008
    static LVIF_IMAGE := 0x00000002
    static LVIS_FOCUSED := 0x00000001
    static LVIS_SELECTED := 0x00000002
    static LVIS_OVERLAYMASK := 0x00000F00
    static ICON_SMALL := 0
    static ICON_BIG := 1
    static LR_LOADFROMFILE := 0x00000010
    static LR_DEFAULTSIZE := 0x00000040
    static LOAD_LIBRARY_AS_DATAFILE := 0x00000002
    static LOAD_LIBRARY_AS_IMAGE_RESOURCE := 0x00000020
    static IMAGE_ICON := 1
    static IMAGE_CURSOR := 2
    static RT_ICON := 3
    static RT_GROUP_ICON := 14
    static GGO_METRICS := 0
    static GDI_ERROR := 0xFFFFFFFF
    static GENERIC_READ := 0x80000000
    static SIIGBF_BIGGERSIZEOK := 0x00000001
    static SIIGBF_THUMBNAILONLY := 0x00000008
    static SIIGBF_SCALEUP := 0x00000100
    static SHGFI_ICON := 0x000000100
    static SHGFI_SMALLICON := 0x000000001
    static SHGFI_LARGEICON := 0x000000000
    static SHGFI_USEFILEATTRIBUTES := 0x000000010
    static SHGFI_SYSICONINDEX := 0x000004000
    static SHGSI_ICON := 0x000000100
    static SHGSI_SYSICONINDEX := 0x000004000
    static SIID_SHIELD := 77
    static FILE_ATTRIBUTE_NORMAL := 0x00000080
    static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
    static TOKEN_QUERY := 0x0008
    static TOKEN_ELEVATION := 20
    static SHIL_EXTRALARGE := 2
    static SHIL_JUMBO := 4
    static ILD_TRANSPARENT := 1
    static MIM_STYLE := 0x00000010
    static MNS_NOCHECK := 0x80000000
    static MIIM_FTYPE := 0x00000100
    static MFT_BITMAP := 0x00000004
    static MFT_OWNERDRAW := 0x00000100
    static MFT_SEPARATOR := 0x00000800
    static ODT_MENU := 1
    static ODS_SELECTED := 0x0001
    static ODS_GRAYED := 0x0002
    static ODS_MENU_DISABLED := 0x0004
    static EVENT_OBJECT_SHOW := 0x8002
    static CTRL_C_EVENT := 0
    static SC_MINIMIZE := 0xF020
    static SC_MAXIMIZE := 0xF030
    static SC_RESTORE := 0xF120
    static GWLP_HWNDPARENT := -8
    static GWL_STYLE := -16
    static GWL_EXSTYLE := -20
    static WS_EX_TOOLWINDOW := 0x80
    static WS_EX_APPWINDOW := 0x40000
    static SW_HIDE := 0
    static SW_MINIMIZE := 6
    static SW_SHOWMINNOACTIVE := 7
    static SMTO_ABORTIFHUNG := 0x0002
    static IDC_ARROW := 32512
    static IDC_IBEAM := 32513
    static HTHSCROLL := 6
    static HTVSCROLL := 7
    static OBJID_HSCROLL := -6
    static OBJID_VSCROLL := -5
    static STATE_SYSTEM_INVISIBLE := 0x00008000
    static STATE_SYSTEM_OFFSCREEN := 0x00010000
    static SB_HORZ := 0
    static SB_VERT := 1
    static SB_BOTH := 3
    static WAIT_OBJECT_0 := 0
    static FILE_LIST_DIRECTORY := 0x0001
    static FILE_SHARE_ALL := 0x00000007
    static OPEN_EXISTING := 3
    static FILE_FLAG_BACKUP_SEMANTICS := 0x02000000
    static FILE_FLAG_OVERLAPPED := 0x40000000
    static FILE_NOTIFY_FILTER := 0x0000005B
    static ERROR_IO_PENDING := 997
    static RDW_BUTTON_REFRESH := 0x0121
    static RDW_LAYOUT_REFRESH := 0x0185 ; 同步重绘父窗口局部区域及其中的子控件。
    static RDW_CONTROL_REFRESH := 0x0105 ; 失效、擦除并同步重绘单个控件。
}

; 首次可见窗口先在 DWM cloak 内完成真实 Show 和同步绘制，再一次性揭示。
; 该类只拥有映射时序，不知道具体控件；调用方通过回调重建自己的可见表面。
class FirstVisibleWindowPresenter {
    static OptionsKeepWindowHidden(showOptions) {
        return RegExMatch(Trim(String(showOptions)),
            "i)(^|\s)Hide(?:\s|$)") != 0
    }

    static SetCloaked(hWnd, cloaked) {
        if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
            return false
        cloakValue := cloaked ? 1 : 0
        try return DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd,
            "Int", Win32.DWMWA_CLOAK, "Int*", cloakValue, "Int", 4,
            "Int") >= 0
        catch
            return false
    }

    static GetCloakState(hWnd) {
        if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
            return 0
        cloakState := 0
        try {
            result := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hWnd,
                "Int", Win32.DWMWA_CLOAKED, "UInt*", &cloakState,
                "Int", 4, "Int")
            return result >= 0 ? cloakState : 0
        } catch {
            return 0
        }
    }

    static FlushComposition() {
        try return DllCall("dwmapi\DwmFlush", "Int") >= 0
        catch
            return false
    }

    static Show(guiObj, showOptions, firstVisibleCompleted,
        prepareVisibleSurface, refreshAfterShow := "") {
        keepHidden := this.OptionsKeepWindowHidden(showOptions)
        if keepHidden || firstVisibleCompleted {
            guiObj.Show(showOptions)
            if !keepHidden && IsObject(refreshAfterShow)
                refreshAfterShow.Call()
            return {
                Visible: !keepHidden,
                FirstVisibleCompleted: !!firstVisibleCompleted,
                CloakApplied: false,
                Uncloaked: true
            }
        }

        previousCritical := A_IsCritical
        cloakApplied := false
        uncloaked := true
        surfacePrepared := false
        Critical("On")
        try {
            cloakApplied := this.SetCloaked(guiObj.Hwnd, true)
            guiObj.Show(showOptions)
            surfacePrepared := !IsObject(prepareVisibleSurface)
                || !!prepareVisibleSurface.Call()
            this.FlushComposition()
        } finally {
            if cloakApplied {
                uncloaked := this.SetCloaked(guiObj.Hwnd, false)
                if !uncloaked {
                    this.FlushComposition()
                    uncloaked := this.SetCloaked(guiObj.Hwnd, false)
                }
            }
            this.FlushComposition()
            Critical(previousCritical ? previousCritical : "Off")
        }
        return {
            Visible: true,
            FirstVisibleCompleted: surfacePrepared
                && (!cloakApplied || uncloaked),
            CloakApplied: cloakApplied,
            Uncloaked: !cloakApplied || uncloaked
        }
    }
}
