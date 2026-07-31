; 主窗口长期状态的唯一所有者。
; 控件、图像列表、右键菜单和路径到行号的投影索引都随主窗口生存，
; 不把短生命周期对话框混入这里，避免下级窗口关闭后留下失效句柄。

class MainWindow {
    __New() {
        this.gui := Gui("+Resize +MinSize580x300", Tr("进程守护小助手"))
        this.lv := ""
        this.listSelectionPresenter := ""
        this.listHeader := ""
        this.btnAdd := ""
        this.btnDel := ""
        this.btnPause := ""
        this.btnSet := ""
        this.btnSupport := ""
        this.btnDonate := ""
        this.settingsButtonWidth := 70
        this.supportButtonWidth := 100
        this.donateButtonWidth := 70
        this.commandButtonGap := 10
        this.commandButtonRightMargin := 10
        this.appIcons := 0
        this.statusIconIndices := Map()
        this.statsText := ""
        this.statsPresenter := ""
        this.contextMenu := ""
        this.contextTargetRow := 0
        this.firstVisiblePresentationCompleted := false
        this.listProjection := MainListProjection(NormalizeTargetPath)
    }
}
