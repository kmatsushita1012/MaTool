import Foundation
import Shared

/// 並列のRoute更新結果を欠落なく記録するテスト専用Spy。
final class RouteUpdateCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Route] = []

    func append(_ route: Route) {
        lock.withLock { stored.append(route) }
    }

    var values: [Route] {
        lock.withLock { stored }
    }
}
