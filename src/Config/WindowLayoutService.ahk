class WindowLayoutService {
    __New(repository) {
        this.Repository := repository
    }

    Load() {
        return {
            Width: this.Repository.ReadBoundedInt("Layout", "GuiW", 730,
                730, 32767),
            Height: this.Repository.ReadBoundedInt("Layout", "GuiH", 530,
                530, 32767),
            Column1: this.Repository.ReadBoundedInt("Layout", "Col1W", 500,
                450, 32767),
            Column2: this.Repository.ReadBoundedInt("Layout", "Col2W", 205,
                205, 32767)
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
            Width: this.RequireDimension(layout, "Width", 730),
            Height: this.RequireDimension(layout, "Height", 530),
            Column1: this.RequireDimension(layout, "Column1", 450),
            Column2: this.RequireDimension(layout, "Column2", 205)
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
