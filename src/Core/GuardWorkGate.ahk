; 守护后台工作的轻量互斥门。
; 普通轮询、重新启动验证和升级保护共享同一入口，避免同一目标被并发修改；
; 临界区只覆盖门状态变更，耗时的外部查询和等待始终在临界区之外执行。

class GuardWorkGate {
    __New() {
        this.Busy := false
    }

    TryEnter() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Busy
                return false
            this.Busy := true
            return true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    Leave() {
        previousCritical := A_IsCritical
        Critical("On")
        try this.Busy := false
        finally Critical(previousCritical ? previousCritical : "Off")
    }
}
