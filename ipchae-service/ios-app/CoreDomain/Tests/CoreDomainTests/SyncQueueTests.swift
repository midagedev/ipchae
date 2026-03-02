import CoreDomain
import XCTest

private actor ValueBox<T: Sendable> {
    private var values: [T] = []

    func append(_ value: T) {
        values.append(value)
    }

    func allValues() -> [T] {
        values
    }
}

final class SyncQueueTests: XCTestCase {
    func testFlushesQueuedPayloadsInOrder() async throws {
        let pushed = ValueBox<String>()

        let queue = SyncQueue<String>(
            pushHandler: { payload in
                await pushed.append(payload)
            }
        )

        await queue.enqueue("a")
        await queue.enqueue("b")

        let drained = await queue.waitUntilDrained(timeoutNanoseconds: 1_000_000_000)
        let values = await pushed.allValues()
        XCTAssertTrue(drained)
        XCTAssertEqual(values, ["a", "b"])
    }

    func testCoalescesPendingPayloadsByKey() async throws {
        struct Payload: Sendable, Equatable {
            var projectID: String
            var seq: Int
        }

        let pushed = ValueBox<Payload>()

        let queue = SyncQueue<Payload>(
            pushHandler: { payload in
                try? await Task.sleep(nanoseconds: 20_000_000)
                await pushed.append(payload)
            },
            coalesceKey: { $0.projectID }
        )

        await queue.enqueue(Payload(projectID: "project-1", seq: 1))
        await queue.enqueue(Payload(projectID: "project-1", seq: 2))
        await queue.enqueue(Payload(projectID: "project-1", seq: 3))

        let drained = await queue.waitUntilDrained(timeoutNanoseconds: 2_000_000_000)
        let values = await pushed.allValues()
        XCTAssertTrue(drained)
        XCTAssertEqual(
            values,
            [Payload(projectID: "project-1", seq: 1), Payload(projectID: "project-1", seq: 3)]
        )
    }
}
