; Persistent state owned by the main window.

class MainWindow {
    __New() {
        this.gui := Gui("+Resize +MinSize730x530", "进程守护小助手")
        this.lv := ""
        this.btnAdd := ""
        this.btnDel := ""
        this.btnPause := ""
        this.btnSet := ""
        this.btnLog := ""
        this.btnHelp := ""
        this.appIcons := 0
        this.statusIconIndices := Map()
        this.statsText := ""
        this.contextMenu := ""
        this.contextTargetRow := 0
        this.listProjection := MainListProjection(NormalizeTargetPath)
    }
}
