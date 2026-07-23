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
