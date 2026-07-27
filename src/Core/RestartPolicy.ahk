; 重新启动等待序列策略。
; 根据连续失败次数选择对应延迟，超过序列后沿用最后一个值进入低频恢复，
; 既避免高速反复拉起，也不会因重试耗尽而永久放弃目标。

class RestartPolicy {
    static NextAfterFailure(failureCount, retryDelays) {
        if !(retryDelays is Array) || !retryDelays.Length
            throw ValueError("重试延迟序列不能为空")
        failureCount := Max(1, Integer(failureCount))
        if (failureCount < retryDelays.Length) {
            return {
                DelayMs: retryDelays[failureCount + 1],
                Attempt: failureCount + 1,
                CoolingDown: false
            }
        }
        return {
            DelayMs: retryDelays[retryDelays.Length],
            Attempt: failureCount + 1,
            CoolingDown: true
        }
    }
}
