; 主窗口尺寸和列表列宽的持久化服务。
; 默认值只用于首次启动或损坏字段，用户拖拽后的尺寸只受最小值约束；
; 窗口与列宽一起原子写入，重新加载后按同一逻辑像素语义恢复。

class WindowLayoutService {
    static StructuralMinimumWidth := 540

    __New(repository) {
        this.Repository := repository
    }

    Load() {
        return {
            Width: this.Repository.ReadBoundedInt("Layout", "GuiW", 730,
                WindowLayoutService.StructuralMinimumWidth, 32767),
            Height: this.Repository.ReadBoundedInt("Layout", "GuiH", 520,
                300, 32767),
            Column1: this.Repository.ReadBoundedInt("Layout", "Col1W", 500,
                200, 32767),
            Column2: this.Repository.ReadBoundedInt("Layout", "Col2W", 200,
                140, 32767)
        }
    }

    Save(layout) {
        normalized := this.Validate(layout)
        this.Repository.WriteValues("Layout", [
            {Key: "GuiW", Value: normalized.Width},
            {Key: "GuiH", Value: normalized.Height},
            {Key: "Col1W", Value: normalized.Column1},
            {Key: "Col2W", Value: normalized.Column2}
        ])
        return normalized
    }

    Apply(runtime, layout) {
        runtime.savedWidth := layout.Width
        runtime.savedHeight := layout.Height
        runtime.savedColumn1 := layout.Column1
        runtime.savedColumn2 := layout.Column2
        return runtime
    }

    Validate(layout) {
        if !IsObject(layout)
            throw TypeError("窗口布局对象无效")
        return {
            Width: this.RequireDimension(layout, "Width",
                WindowLayoutService.StructuralMinimumWidth),
            Height: this.RequireDimension(layout, "Height", 300),
            Column1: this.RequireDimension(layout, "Column1", 200),
            Column2: this.RequireDimension(layout, "Column2", 140)
        }
    }

    RequireDimension(layout, propertyName, minimum) {
        if !layout.HasOwnProp(propertyName)
            throw ValueError("缺少窗口布局字段: " propertyName)
        try value := Integer(layout.%propertyName%)
        catch
            throw ValueError("窗口布局字段不是整数: " propertyName)
        if (value < minimum || value > 32767)
            throw ValueError("窗口布局字段超出范围: " propertyName)
        return value
    }
}
