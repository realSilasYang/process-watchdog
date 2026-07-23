class IconResourceRegistry {
    __New() {
        this.IconCache := Map()
        this.IconCache.CaseSense := "Off"
        this.WindowIconPairs := Map()
        this.MainImageListUsers := Map()
        this.RetiredMainImageLists := Map()
        this.ResamplerFactory := 0
        this.MainDpi := 96
        this.MainIconPixelSize := 28
        this.MainIconCellPixelSize := 36
        this.DpiRebuildTimer := 0
        this.DpiRebuildGeneration := 0
    }

    HasCachedIcon(imageList, filePath) {
        return this.IconCache.Has(this.IconCacheKey(imageList, filePath))
    }

    GetCachedIcon(imageList, filePath) {
        key := this.IconCacheKey(imageList, filePath)
        return this.IconCache.Has(key) ? this.IconCache[key] : 0
    }

    StoreCachedIcon(imageList, filePath, iconIndex) {
        if !imageList || !iconIndex
            return false
        this.IconCache[this.IconCacheKey(imageList, filePath)] := iconIndex
        return true
    }

    ClearImageListCache(imageList) {
        if !imageList
            return 0
        prefix := String(imageList) "_"
        staleKeys := []
        for cacheKey in this.IconCache {
            if InStr(cacheKey, prefix) == 1
                staleKeys.Push(cacheKey)
        }
        for cacheKey in staleKeys
            this.IconCache.Delete(cacheKey)
        return staleKeys.Length
    }

    ClearCache() {
        count := this.IconCache.Count
        this.IconCache.Clear()
        return count
    }

    IconCacheKey(imageList, filePath) {
        return String(imageList) "_" String(filePath)
    }

    ReplaceWindowIcons(hwnd, iconPair) {
        if !hwnd || !IsObject(iconPair)
            return ""
        previousPair := this.WindowIconPairs.Has(hwnd)
            ? this.WindowIconPairs[hwnd] : []
        this.WindowIconPairs[hwnd] := iconPair
        return previousPair
    }

    TakeWindowIcons(hwnd) {
        if !hwnd || !this.WindowIconPairs.Has(hwnd)
            return ""
        iconPair := this.WindowIconPairs[hwnd]
        this.WindowIconPairs.Delete(hwnd)
        return iconPair
    }

    AcquireMainImageList(imageList, activeImageList) {
        if !imageList
            return 0
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if (imageList != activeImageList
                && !this.RetiredMainImageLists.Has(imageList))
                return 0
            this.MainImageListUsers[imageList] :=
                this.MainImageListUsers.Get(imageList, 0) + 1
            return imageList
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    ReleaseMainImageList(imageList) {
        if !imageList
            return false
        destroyNow := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.MainImageListUsers.Has(imageList)
                return false
            remainingUsers := this.MainImageListUsers[imageList] - 1
            if (remainingUsers > 0) {
                this.MainImageListUsers[imageList] := remainingUsers
                return false
            }
            this.MainImageListUsers.Delete(imageList)
            if this.RetiredMainImageLists.Has(imageList) {
                this.RetiredMainImageLists.Delete(imageList)
                destroyNow := true
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        return destroyNow
    }

    RetireMainImageList(imageList, activeImageList) {
        if !imageList
            return false
        destroyNow := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if (imageList == activeImageList)
                return false
            if (this.MainImageListUsers.Has(imageList)
                && this.MainImageListUsers[imageList] > 0) {
                this.RetiredMainImageLists[imageList] := true
            } else {
                if this.MainImageListUsers.Has(imageList)
                    this.MainImageListUsers.Delete(imageList)
                if this.RetiredMainImageLists.Has(imageList)
                    this.RetiredMainImageLists.Delete(imageList)
                destroyNow := true
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        return destroyNow
    }

    IsMainImageListTracked(imageList, activeImageList) {
        return imageList && (imageList == activeImageList
            || this.MainImageListUsers.Has(imageList)
            || this.RetiredMainImageLists.Has(imageList))
    }

    GetMainImageListUseCount(imageList) {
        return this.MainImageListUsers.Get(imageList, 0)
    }

    IsMainImageListRetired(imageList) {
        return imageList && this.RetiredMainImageLists.Has(imageList)
    }

    GetMainIconMetrics() {
        return {
            Dpi: this.MainDpi,
            IconPixelSize: this.MainIconPixelSize,
            CellPixelSize: this.MainIconCellPixelSize
        }
    }

    UpdateMainIconMetrics(dpi) {
        try dpi := Integer(dpi)
        catch
            return false
        if (dpi < 1)
            return false
        this.MainDpi := dpi
        this.MainIconPixelSize := Max(20, Round(28 * dpi / 96))
        this.MainIconCellPixelSize := Max(this.MainIconPixelSize + 2,
            Round(36 * dpi / 96))
        return true
    }

    RestoreMainIconMetrics(metrics) {
        if !IsObject(metrics) || !metrics.HasOwnProp("Dpi")
            || !metrics.HasOwnProp("IconPixelSize")
            || !metrics.HasOwnProp("CellPixelSize")
            return false
        this.MainDpi := metrics.Dpi
        this.MainIconPixelSize := metrics.IconPixelSize
        this.MainIconCellPixelSize := metrics.CellPixelSize
        return true
    }

    GetResamplerFactory() {
        return this.ResamplerFactory
    }

    InstallResamplerFactory(factory) {
        if !factory
            return false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.ResamplerFactory
                return false
            this.ResamplerFactory := factory
            return true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    TakeResamplerFactory() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            factory := this.ResamplerFactory
            this.ResamplerFactory := 0
            return factory
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    CreateDpiRebuildRequest(expectedDpi, rebuildCallback) {
        if !IsObject(rebuildCallback)
            throw TypeError("DPI 图标重建回调无效")
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.DpiRebuildGeneration++
            generation := this.DpiRebuildGeneration
            previousTimer := this.DpiRebuildTimer
            timer := rebuildCallback.Bind(generation, expectedDpi)
            this.DpiRebuildTimer := timer
            return {
                Generation: generation,
                ExpectedDpi: expectedDpi,
                PreviousTimer: previousTimer,
                Timer: timer
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    AcceptDpiRebuild(generation) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if (generation != this.DpiRebuildGeneration
                || !this.DpiRebuildTimer)
                return false
            this.DpiRebuildTimer := 0
            return true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    IsDpiRebuildCurrent(generation) {
        previousCritical := A_IsCritical
        Critical("On")
        try return generation == this.DpiRebuildGeneration
        finally Critical(previousCritical ? previousCritical : "Off")
    }

    CancelDpiRebuild() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            timer := this.DpiRebuildTimer
            this.DpiRebuildTimer := 0
            this.DpiRebuildGeneration++
            return timer
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }
}
