import Foundation

public enum SyncStatus: String, Codable, Sendable {
    case local
    case syncing
    case synced
    case failed
}

public actor SyncQueue<Payload: Sendable> {
    public typealias PushHandler = @Sendable (Payload) async throws -> Void
    public typealias CoalesceKeyProvider = @Sendable (Payload) -> String?
    public typealias SleepHandler = @Sendable (UInt64) async -> Void

    private struct QueueJob: Sendable {
        var id: String
        var payload: Payload
        var retry: Int
        var coalesceKey: String?
    }

    private let pushHandler: PushHandler
    private let coalesceKeyProvider: CoalesceKeyProvider?
    private let sleepHandler: SleepHandler
    private let baseRetryDelayMs: UInt64
    private let maxRetryDelayMs: UInt64

    private var queue: [QueueJob] = []
    private var flushing = false

    public init(
        pushHandler: @escaping PushHandler,
        coalesceKey: CoalesceKeyProvider? = nil,
        sleepHandler: @escaping SleepHandler = { nanos in
            try? await Task.sleep(nanoseconds: nanos)
        },
        baseRetryDelayMs: UInt64 = 1_000,
        maxRetryDelayMs: UInt64 = 15_000
    ) {
        self.pushHandler = pushHandler
        self.coalesceKeyProvider = coalesceKey
        self.sleepHandler = sleepHandler
        self.baseRetryDelayMs = baseRetryDelayMs
        self.maxRetryDelayMs = maxRetryDelayMs
    }

    public func enqueue(_ payload: Payload) {
        let candidateKey = coalesceKeyProvider?(payload)

        if let candidateKey {
            let startIndex = flushing ? 1 : 0
            if let existingIndex = queue.indices.first(where: { index in
                index >= startIndex && queue[index].coalesceKey == candidateKey
            }) {
                queue[existingIndex].payload = payload
                return
            }
        }

        queue.append(
            QueueJob(
                id: "sync-\(Date().timeIntervalSince1970)-\(UUID().uuidString)",
                payload: payload,
                retry: 0,
                coalesceKey: candidateKey
            )
        )

        if !flushing {
            flushing = true
            Task {
                await flushLoop()
            }
        }
    }

    public func size() -> Int {
        queue.count
    }

    public func waitUntilDrained(timeoutNanoseconds: UInt64 = 5_000_000_000) async -> Bool {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        while true {
            if queue.isEmpty, !flushing {
                return true
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
            if elapsed >= timeoutNanoseconds {
                return false
            }
            await sleepHandler(10_000_000)
        }
    }

    private func flushLoop() async {
        while !queue.isEmpty {
            var current = queue[0]
            do {
                try await pushHandler(current.payload)
                queue.removeFirst()
            } catch {
                current.retry += 1
                queue[0] = current
                let delayMs = retryDelayMs(forRetry: current.retry)
                await sleepHandler(delayMs * 1_000_000)
            }
        }

        flushing = false

        // enqueue가 flush 종료 직전에 들어왔을 수 있어, drain 직후 한번 더 확인.
        if !queue.isEmpty {
            flushing = true
            await flushLoop()
        }
    }

    private func retryDelayMs(forRetry retry: Int) -> UInt64 {
        if retry <= 1 {
            return min(baseRetryDelayMs, maxRetryDelayMs)
        }

        var delay = baseRetryDelayMs
        for _ in 1..<retry {
            if delay >= maxRetryDelayMs {
                return maxRetryDelayMs
            }
            delay = min(delay * 2, maxRetryDelayMs)
        }
        return delay
    }
}
