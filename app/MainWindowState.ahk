; 主窗口长期状态的唯一所有者。
; 控件、图像列表、右键菜单和路径到行号的投影索引都随主窗口生存，
; 不把短生命周期对话框混入这里，避免下级窗口关闭后留下失效句柄。

class MainWindow {
    static SmoothScrollFastIntervalMs := 12
    static SmoothScrollSlowIntervalMs := 40
    static SmoothScrollAccelerationLines := 8
    static SmoothScrollMaximumQueuedLines := 18
    static SmoothScrollTimerResolutionMs := 1
    static WheelDelta := 120
    static ListWheelSubclassId := 0x50575343
    static SequenceDotDiameterDip := 8
    static SequenceColumn := 4

    __New() {
        this.gui := Gui("+Resize +MinSize"
            WindowLayoutService.StructuralMinimumWidth "x300",
            Tr("进程守护小助手"))
        this.lv := ""
        this.listSelectionPresenter := ""
        this.listHeader := ""
        this.btnAdd := ""
        this.btnDel := ""
        this.btnPause := ""
        this.btnSet := ""
        this.btnSupport := ""
        this.btnAbout := ""
        this.settingsButtonWidth := 70
        this.supportButtonWidth := 100
        this.aboutButtonWidth := 70
        this.commandButtonGap := 10
        this.commandButtonRightMargin := 10
        this.appIcons := 0
        this.statusIconIndices := Map()
        this.statsText := ""
        this.statsPresenter := ""
        this.contextMenu := ""
        this.contextPopup := MainContextPopupWindow(this.gui)
        this.contextTargetRow := 0
        this.firstVisiblePresentationCompleted := false
        this.listWheelSubclassCallback := 0
        this.listWheelSubclassAttached := false
        this.listWheelCallback := 0
        this.listWheelRegistered := false
        this.smoothListScrollTimer := AdvanceMainListSmoothScroll
        this.pendingListScrollLines := 0
        this.listWheelDeltaRemainder := 0
        this.lastSmoothListScrollIntervalMs := 0
        this.smoothListTimerResolutionActive := false
        this.listDragActive := false
        this.listProjection := MainListProjection(NormalizeTargetPath)
    }
}
