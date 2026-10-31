import Testing
@testable import iOSApp

struct AsyncTests {
    @Test("タイムアウト時にキャンセルへ応答しない処理を待ち続けない")
    func timeoutReturnsWithoutWaitingForUncooperativeOperation() async {
        let gate = ContinuationGate()

        do {
            _ = try await withTimeout(seconds: 0) {
                await gate.wait()
                return "finished"
            }
            Issue.record("タイムアウトが返りませんでした")
        } catch let error as AppError {
            #expect(error == .auth(.timeout("タイムアウトしました")))
        } catch {
            Issue.record("想定外のエラー: \(error)")
        }

        await gate.release()
    }

    @Test("キャンセル時に処理のタイムアウトを待たずに戻る")
    func cancellationReturnsWithoutWaitingForOperation() async {
        let gate = ContinuationGate()
        let operation = Task {
            try await withTimeout(seconds: 60) {
                await gate.wait()
                return "finished"
            }
        }

        operation.cancel()
        var didCancel = false

        do {
            _ = try await operation.value
            Issue.record("キャンセルが伝播しませんでした")
        } catch is CancellationError {
            didCancel = true
        } catch {
            Issue.record("想定外のエラー: \(error)")
        }

        #expect(didCancel)
        await gate.release()
    }
}

private actor ContinuationGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func wait() async {
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}
