class RuntimeSettingsService {
    __New(repository, parseRetrySequence, defaultLogDirectory) {
        this.Repository := repository
        this.ParseRetrySequence := parseRetrySequence
        this.DefaultLogDirectory := defaultLogDirectory
    }

    EnsureExists() {
        defaults := this.CreateDefaults()
        return this.Repository.EnsureExists([{Name: "Settings", Entries:
            this.CreateEntries(defaults, true)}])
    }

    Load() {
        defaults := this.CreateDefaults()
        settings := {
            CheckInterval: this.Repository.ReadBoundedInt("Settings",
                "CheckInterval", defaults.CheckInterval, 500, 86400000),
            RetrySequence: this.Repository.Read("Settings", "RetrySequence",
                defaults.RetrySequence),
            ShowAtStartup: this.Repository.ReadBool("Settings",
                "ShowAtStartup", defaults.ShowAtStartup),
            RecursiveBatchImport: this.Repository.ReadBool("Settings",
                "RecursiveBatchImport", defaults.RecursiveBatchImport),
            LogMaxEntries: this.Repository.ReadBoundedInt("Settings",
                "LogMaxEntries", defaults.LogMaxEntries, 50, 10000),
            LogDirectory: this.Repository.Read("Settings", "LogDirectory",
                defaults.LogDirectory),
            LogRetentionDays: this.Repository.ReadBoundedInt("Settings",
                "LogRetentionDays", defaults.LogRetentionDays, 1, 3650),
            ClearLogsOnStartup: this.Repository.ReadBool("Settings",
                "ClearLogsOnStartup", defaults.ClearLogsOnStartup),
            GracefulStopSeconds: this.Repository.ReadBoundedInt("Settings",
                "GracefulStopSeconds", defaults.GracefulStopSeconds, 1, 300),
            CtrlCWaitSeconds: this.Repository.ReadBoundedInt("Settings",
                "CtrlCWaitSeconds", defaults.CtrlCWaitSeconds, 1, 60),
            AllowForceTerminate: this.Repository.ReadBool("Settings",
                "AllowForceTerminate", defaults.AllowForceTerminate),
            PreferEverything: this.Repository.ReadBool("Settings",
                "PreferEverything", defaults.PreferEverything),
            NativeScanTimeoutSeconds: this.Repository.ReadBoundedInt(
                "Settings", "NativeScanTimeoutSeconds",
                defaults.NativeScanTimeoutSeconds, 1, 120),
            EverythingMaxResults: this.Repository.ReadBoundedInt("Settings",
                "EverythingMaxResults", defaults.EverythingMaxResults,
                10, 1000)
        }
        try settings.LogDirectory := Trim(String(settings.LogDirectory))
        catch
            settings.LogDirectory := defaults.LogDirectory
        if (settings.LogDirectory == "")
            settings.LogDirectory := defaults.LogDirectory
        try retryDelays := this.ParseRetrySequence.Call(
            settings.RetrySequence)
        catch
            retryDelays := false
        if !retryDelays {
            settings.RetrySequence := defaults.RetrySequence
            retryDelays := defaults.RetryDelayArray
        }
        settings.RetryDelayArray := this.CloneArray(retryDelays)
        return settings
    }

    Save(settings) {
        normalized := this.Validate(settings)
        this.Repository.WriteValues("Settings",
            this.CreateEntries(normalized, false))
        return normalized
    }

    Apply(runtime, settings) {
        runtime.checkInterval := settings.CheckInterval
        runtime.retrySequence := settings.RetrySequence
        runtime.retryDelayArray := this.CloneArray(settings.RetryDelayArray)
        runtime.showAtStartup := !!settings.ShowAtStartup
        runtime.recursiveBatchImport := !!settings.RecursiveBatchImport
        runtime.logMaxEntries := settings.LogMaxEntries
        runtime.logDirectory := settings.LogDirectory
        runtime.logRetentionDays := settings.LogRetentionDays
        runtime.clearLogsOnStartup := !!settings.ClearLogsOnStartup
        runtime.gracefulStopSeconds := settings.GracefulStopSeconds
        runtime.ctrlCWaitSeconds := settings.CtrlCWaitSeconds
        runtime.allowForceTerminate := !!settings.AllowForceTerminate
        runtime.preferEverything := !!settings.PreferEverything
        runtime.nativeScanTimeoutSeconds := settings.NativeScanTimeoutSeconds
        runtime.everythingMaxResults := settings.EverythingMaxResults
        return runtime
    }

    Validate(settings) {
        if !IsObject(settings)
            throw TypeError("运行参数对象无效")
        normalized := {
            CheckInterval: this.RequireInteger(settings, "CheckInterval",
                500, 86400000),
            RetrySequence: this.RequireText(settings, "RetrySequence"),
            ShowAtStartup: this.RequireBoolean(settings, "ShowAtStartup"),
            RecursiveBatchImport: this.RequireBoolean(settings,
                "RecursiveBatchImport"),
            LogMaxEntries: this.RequireInteger(settings, "LogMaxEntries",
                50, 10000),
            LogDirectory: this.RequireText(settings, "LogDirectory"),
            LogRetentionDays: this.RequireInteger(settings,
                "LogRetentionDays", 1, 3650),
            ClearLogsOnStartup: this.RequireBoolean(settings,
                "ClearLogsOnStartup"),
            GracefulStopSeconds: this.RequireInteger(settings,
                "GracefulStopSeconds", 1, 300),
            CtrlCWaitSeconds: this.RequireInteger(settings,
                "CtrlCWaitSeconds", 1, 60),
            AllowForceTerminate: this.RequireBoolean(settings,
                "AllowForceTerminate"),
            PreferEverything: this.RequireBoolean(settings,
                "PreferEverything"),
            NativeScanTimeoutSeconds: this.RequireInteger(settings,
                "NativeScanTimeoutSeconds", 1, 120),
            EverythingMaxResults: this.RequireInteger(settings,
                "EverythingMaxResults", 10, 1000)
        }
        retryDelays := this.ParseRetrySequence.Call(normalized.RetrySequence)
        if !retryDelays
            throw ValueError("重试延迟序列无效")
        normalized.RetryDelayArray := this.CloneArray(retryDelays)
        return normalized
    }

    CreateDefaults() {
        return {
            CheckInterval: 2000,
            RetrySequence: "1, 10, 60",
            RetryDelayArray: [1000, 10000, 60000],
            ShowAtStartup: false,
            RecursiveBatchImport: true,
            LogMaxEntries: 500,
            LogDirectory: this.DefaultLogDirectory,
            LogRetentionDays: 30,
            ClearLogsOnStartup: false,
            GracefulStopSeconds: 3,
            CtrlCWaitSeconds: 2,
            AllowForceTerminate: true,
            PreferEverything: true,
            NativeScanTimeoutSeconds: 15,
            EverythingMaxResults: 80
        }
    }

    CreateEntries(settings, includeReloadMarker := false) {
        entries := [
            {Key: "CheckInterval", Value: settings.CheckInterval},
            {Key: "RetrySequence", Value: settings.RetrySequence}
        ]
        if includeReloadMarker
            entries.Push({Key: "ShowAfterReload", Value: 0})
        entries.Push(
            {Key: "ShowAtStartup", Value: settings.ShowAtStartup ? 1 : 0},
            {Key: "RecursiveBatchImport",
                Value: settings.RecursiveBatchImport ? 1 : 0},
            {Key: "LogMaxEntries", Value: settings.LogMaxEntries},
            {Key: "LogDirectory", Value: settings.LogDirectory},
            {Key: "LogRetentionDays", Value: settings.LogRetentionDays},
            {Key: "ClearLogsOnStartup",
                Value: settings.ClearLogsOnStartup ? 1 : 0},
            {Key: "GracefulStopSeconds", Value: settings.GracefulStopSeconds},
            {Key: "CtrlCWaitSeconds", Value: settings.CtrlCWaitSeconds},
            {Key: "AllowForceTerminate",
                Value: settings.AllowForceTerminate ? 1 : 0},
            {Key: "PreferEverything", Value: settings.PreferEverything ? 1 : 0},
            {Key: "NativeScanTimeoutSeconds",
                Value: settings.NativeScanTimeoutSeconds},
            {Key: "EverythingMaxResults", Value: settings.EverythingMaxResults}
        )
        return entries
    }

    RequireInteger(settings, propertyName, minimum, maximum) {
        if !settings.HasOwnProp(propertyName)
            throw ValueError("缺少运行参数: " propertyName)
        try value := Integer(settings.%propertyName%)
        catch
            throw ValueError("运行参数不是整数: " propertyName)
        if (value < minimum || value > maximum)
            throw ValueError("运行参数超出范围: " propertyName)
        return value
    }

    RequireText(settings, propertyName) {
        if !settings.HasOwnProp(propertyName)
            throw ValueError("缺少运行参数: " propertyName)
        value := Trim(String(settings.%propertyName%))
        if (value == "")
            throw ValueError("运行参数不能为空: " propertyName)
        return value
    }

    RequireBoolean(settings, propertyName) {
        if !settings.HasOwnProp(propertyName)
            throw ValueError("缺少运行参数: " propertyName)
        return !!settings.%propertyName%
    }

    CloneArray(values) {
        clone := []
        for value in values
            clone.Push(value)
        return clone
    }
}
