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
