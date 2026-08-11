; 守护后台工作的轻量互斥门。
; 普通轮询、重新启动验证和升级保护共享同一入口，避免同一目标被并发修改；
; 临界区只覆盖门状态变更，耗时的外部查询和等待始终在临界区之外执行。

class GuardWorkGate {
    __New(clock := "", logger := "", warningThreshold := 5,
        warningIntervalMs := 30000) {
        this.Clock := clock
        this.Logger := logger
        this.WarningThreshold := Max(1, Integer(warningThreshold))
        this.WarningIntervalMs := Max(1000, Integer(warningIntervalMs))
        this.Busy := false
        this.CurrentOwner := ""
        this.AcquiredAtTicks := 0
        this.LastOwner := ""
        this.LastHoldMs := 0
        this.LongestHoldMs := 0
        this.TotalHoldMs := 0
        this.AcquisitionCount := 0
        this.ContentionCount := 0
        this.ConsecutiveContentions := 0
        this.LastContentionTicks := 0
        this.LastWarningTicks := 0
        this.WarningCount := 0
        this.ContentionByRequester := Map()
        this.ContentionByRequester.CaseSense := "Off"
        this.ContentionByBlockingOwner := Map()
        this.ContentionByBlockingOwner.CaseSense := "Off"
    }

    TryEnter(owner := "Unspecified") {
        owner := this.NormalizeOwner(owner)
        nowTicks := this.Now()
        acquired := false
        warning := ""
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Busy {
                this.ContentionCount++
                this.ConsecutiveContentions++
                this.LastContentionTicks := nowTicks
                this.IncrementCounter(this.ContentionByRequester, owner)
                blockingOwner := this.CurrentOwner != ""
                    ? this.CurrentOwner : "Unknown"
                this.IncrementCounter(this.ContentionByBlockingOwner,
                    blockingOwner)
                if (this.ConsecutiveContentions >= this.WarningThreshold
                    && (!this.LastWarningTicks
                        || nowTicks - this.LastWarningTicks
                            >= this.WarningIntervalMs)) {
                    this.LastWarningTicks := nowTicks
                    this.WarningCount++
                    warning := {
                        Requester: owner,
                        Owner: blockingOwner,
                        Consecutive: this.ConsecutiveContentions,
                        HeldMs: this.CurrentHoldDuration(nowTicks)
                    }
                }
            } else {
                this.Busy := true
                this.CurrentOwner := owner
                this.AcquiredAtTicks := nowTicks
                this.AcquisitionCount++
                this.ConsecutiveContentions := 0
                acquired := true
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if IsObject(warning)
            this.LogSustainedContention(warning)
        return acquired
    }

    Leave() {
        nowTicks := this.Now()
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.Busy
                return false
            holdMs := this.CurrentHoldDuration(nowTicks)
            this.LastOwner := this.CurrentOwner
            this.LastHoldMs := holdMs
            this.LongestHoldMs := Max(this.LongestHoldMs, holdMs)
            this.TotalHoldMs += holdMs
            this.Busy := false
            this.CurrentOwner := ""
            this.AcquiredAtTicks := 0
            return true
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    Snapshot() {
        nowTicks := this.Now()
        previousCritical := A_IsCritical
        Critical("On")
        try {
            requesterCounts := this.CloneMap(this.ContentionByRequester)
            blockingOwnerCounts := this.CloneMap(
                this.ContentionByBlockingOwner)
            return {
                Busy: this.Busy,
                CurrentOwner: this.CurrentOwner,
                AcquiredAtTicks: this.AcquiredAtTicks,
                CurrentHoldMs: this.CurrentHoldDuration(nowTicks),
                LastOwner: this.LastOwner,
                LastHoldMs: this.LastHoldMs,
                LongestHoldMs: this.LongestHoldMs,
                TotalHoldMs: this.TotalHoldMs,
                AcquisitionCount: this.AcquisitionCount,
                ContentionCount: this.ContentionCount,
                ConsecutiveContentions: this.ConsecutiveContentions,
                LastContentionTicks: this.LastContentionTicks,
                LastWarningTicks: this.LastWarningTicks,
                WarningCount: this.WarningCount,
                ContentionByRequester: requesterCounts,
                ContentionByBlockingOwner: blockingOwnerCounts
            }
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    BuildDiagnosticText(prefix := "GuardWorkGate") {
        snapshot := this.Snapshot()
        averageHoldMs := snapshot.AcquisitionCount
            ? Round(snapshot.TotalHoldMs / snapshot.AcquisitionCount) : 0
        text := prefix ".Busy=" (snapshot.Busy ? 1 : 0) "`r`n"
            . prefix ".CurrentOwner=" snapshot.CurrentOwner "`r`n"
            . prefix ".AcquiredAtTicks=" snapshot.AcquiredAtTicks "`r`n"
            . prefix ".CurrentHoldMs=" snapshot.CurrentHoldMs "`r`n"
            . prefix ".LastOwner=" snapshot.LastOwner "`r`n"
            . prefix ".LastHoldMs=" snapshot.LastHoldMs "`r`n"
            . prefix ".LongestHoldMs=" snapshot.LongestHoldMs "`r`n"
            . prefix ".AverageHoldMs=" averageHoldMs "`r`n"
            . prefix ".AcquisitionCount=" snapshot.AcquisitionCount "`r`n"
            . prefix ".ContentionCount=" snapshot.ContentionCount "`r`n"
            . prefix ".ConsecutiveContentions="
                . snapshot.ConsecutiveContentions "`r`n"
            . prefix ".LastContentionTicks="
                . snapshot.LastContentionTicks "`r`n"
            . prefix ".WarningCount=" snapshot.WarningCount "`r`n"
        for requester, count in snapshot.ContentionByRequester
            text .= prefix ".ContentionByRequester."
                . this.DiagnosticKey(requester) "=" count "`r`n"
        for owner, count in snapshot.ContentionByBlockingOwner
            text .= prefix ".ContentionByBlockingOwner."
                . this.DiagnosticKey(owner) "=" count "`r`n"
        return text
    }

    CurrentHoldDuration(nowTicks) {
        return this.Busy && this.AcquiredAtTicks
            && nowTicks >= this.AcquiredAtTicks
            ? nowTicks - this.AcquiredAtTicks : 0
    }

    IncrementCounter(counters, key) {
        counters[key] := counters.Has(key) ? counters[key] + 1 : 1
    }

    CloneMap(source) {
        clone := Map()
        clone.CaseSense := source.CaseSense
        for key, value in source
            clone[key] := value
        return clone
    }

    NormalizeOwner(owner) {
        owner := Trim(String(owner))
        if owner == ""
            owner := "Unspecified"
        owner := RegExReplace(owner, "[\r\n=]+", "_")
        return SubStr(owner, 1, 80)
    }

    DiagnosticKey(value) {
        value := RegExReplace(this.NormalizeOwner(value),
            "[^A-Za-z0-9_.-]", "_")
        return value != "" ? value : "Unknown"
    }

    LogSustainedContention(warning) {
        if !IsObject(this.Logger)
            return
        try this.Logger.Call("GuardWorkGate|SustainedContention|Requester="
            . warning.Requester "|Owner=" warning.Owner "|Consecutive="
            . warning.Consecutive "|HeldMs=" warning.HeldMs)
    }

    Now() {
        if IsObject(this.Clock) {
            try return Integer(this.Clock.Call())
        }
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
