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
    private static let retryDelays: [Duration] = [
        .seconds(1),
        .seconds(2),
        .seconds(4)
    ]

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MaTool",
        category: "StoreAdImpressionQueue"
    )

    @Dependency(StoreAdDataFetcherKey.self) private var dataFetcher
    @Dependency(\.continuousClock) private var clock

    private var pending: [ImpressionReportRequest] = []
    private var enqueuedImpressionIDs: Set<String> = []
    private var worker: Task<Void, Never>?

    func enqueue(_ request: ImpressionReportRequest) async {
        guard enqueuedImpressionIDs.insert(request.impressionId).inserted else {
            logger.debug("Duplicate impression enqueue ignored impressionId=\(request.impressionId, privacy: .public)")
            return
        }

        pending.append(request)
        logger.info("Impression queued impressionId=\(request.impressionId, privacy: .public)")
        guard worker == nil else { return }
        worker = Task { await processPending() }
    }

    private func processPending() async {
        while !pending.isEmpty {
            let request = pending[0]
            await reportWithRetry(request)
            pending.removeFirst()
        }
        worker = nil
    }

    private func reportWithRetry(_ request: ImpressionReportRequest) async {
        var retryCount = 0

        while true {
            do {
                try await dataFetcher.reportImpression(request)
                logger.info("Impression report succeeded impressionId=\(request.impressionId, privacy: .public)")
                return
            } catch {
                guard let delay = Self.retryDelay(for: error, retryCount: retryCount) else {
                    logger.error("Impression report dropped impressionId=\(request.impressionId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return
                }

                retryCount += 1
                logger.warning("Retrying impression report impressionId=\(request.impressionId, privacy: .public) retry=\(retryCount)")
                do {
                    try await clock.sleep(for: delay)
                } catch {
                    logger.error("Impression retry cancelled impressionId=\(request.impressionId, privacy: .public)")
                    return
                }
            }
        }
    }

    static func retryDelay(for error: Error, retryCount: Int) -> Duration? {
        guard retryCount < retryDelays.count,
              let error = error as? AppError else {
            return nil
        }

        let isTransient: Bool
        switch error {
        case .be(.network), .be(.timeout):
            isTransient = true
        case .be(.server(let statusCode, _)):
            isTransient = statusCode == 429 || (500...599).contains(statusCode)
        default:
            isTransient = false
        }

        return isTransient ? retryDelays[retryCount] : nil
    }
}

enum StoreAdImpressionQueueClientKey: DependencyKey {
    static let liveValue: any StoreAdImpressionQueueClientProtocol = StoreAdImpressionQueueClient()
}
