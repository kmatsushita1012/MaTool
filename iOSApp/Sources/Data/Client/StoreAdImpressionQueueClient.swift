import Dependencies
import Foundation
import os
import Shared

extension DependencyValues {
    var storeAdImpressionQueueClient: any StoreAdImpressionQueueClientProtocol {
        get { self[StoreAdImpressionQueueClientKey.self] }
        set { self[StoreAdImpressionQueueClientKey.self] = newValue }
    }
}

protocol StoreAdImpressionQueueClientProtocol: Sendable {
    func enqueue(_ request: ImpressionReportRequest) async
}

actor StoreAdImpressionQueueClient: StoreAdImpressionQueueClientProtocol {
    private static let maximumAttemptsPerFlush = 4
    private static let maximumRetryDelaySeconds = 60

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MaTool",
        category: "StoreAdImpressionQueue"
    )

    @Dependency(StoreAdDataFetcherKey.self) private var dataFetcher
    @Dependency(\.continuousClock) private var clock

    private struct PendingRequest {
        let request: ImpressionReportRequest
        var consecutiveFailureCount = 0
    }

    private var pending: [PendingRequest] = []
    private var enqueuedImpressionIDs: Set<String> = []
    private var worker: Task<Void, Never>?
    private var flushRequested = false

    func enqueue(_ request: ImpressionReportRequest) async {
        if enqueuedImpressionIDs.insert(request.impressionId).inserted {
            pending.append(PendingRequest(request: request))
            logger.info("Impression queued impressionId=\(request.impressionId, privacy: .public)")
        } else {
            logger.debug("Duplicate impression enqueue ignored impressionId=\(request.impressionId, privacy: .public)")
        }

        flushRequested = true
        guard worker == nil else { return }
        worker = Task { await processPending() }
    }

    private func processPending() async {
        while !pending.isEmpty {
            flushRequested = false
            await flushPending()
            guard flushRequested, !pending.isEmpty else { break }
        }
        worker = nil
    }

    private func flushPending() async {
        pendingLoop: while !pending.isEmpty {
            var attempts = 0

            while attempts < Self.maximumAttemptsPerFlush {
                let queuedRequest = pending[0]
                if queuedRequest.consecutiveFailureCount > 0 {
                    do {
                        try await clock.sleep(
                            for: Self.retryDelay(consecutiveFailureCount: queuedRequest.consecutiveFailureCount)
                        )
                    } catch {
                        logger.error("Impression retry cancelled impressionId=\(queuedRequest.request.impressionId, privacy: .public)")
                        return
                    }
                }

                attempts += 1
                do {
                    try await dataFetcher.reportImpression(queuedRequest.request)
                    pending.removeFirst()
                    logger.info("Impression report succeeded impressionId=\(queuedRequest.request.impressionId, privacy: .public)")
                    continue pendingLoop
                } catch {
                    guard Self.isRetryable(error) else {
                        pending.removeFirst()
                        logger.error("Impression report dropped impressionId=\(queuedRequest.request.impressionId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        continue pendingLoop
                    }

                    pending[0].consecutiveFailureCount += 1
                    let failureCount = pending[0].consecutiveFailureCount
                    if attempts == Self.maximumAttemptsPerFlush {
                        logger.warning("Impression report deferred until the next enqueue impressionId=\(queuedRequest.request.impressionId, privacy: .public) failures=\(failureCount)")
                        return
                    }

                    logger.warning("Retrying impression report impressionId=\(queuedRequest.request.impressionId, privacy: .public) failure=\(failureCount)")
                }
            }
        }
    }

    static func isRetryable(_ error: Error) -> Bool {
        guard let error = error as? AppError else { return false }
        switch error {
        case .be(.network), .be(.timeout):
            return true
        case .be(.server(let statusCode, _)):
            return statusCode == 429 || (500...599).contains(statusCode)
        default:
            return false
        }
    }

    static func retryDelay(consecutiveFailureCount: Int) -> Duration {
        let exponent = min(max(consecutiveFailureCount - 1, 0), 6)
        let seconds = min(1 << exponent, maximumRetryDelaySeconds)
        return .seconds(seconds)
    }
}

enum StoreAdImpressionQueueClientKey: DependencyKey {
    static let liveValue: any StoreAdImpressionQueueClientProtocol = StoreAdImpressionQueueClient()
}
