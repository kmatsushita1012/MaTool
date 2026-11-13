import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct StoreAdImpressionQueueClientTests {
    @Test("一時的なサーバーエラーは同じIDとtokenで再送する")
    func retriesTransientFailureWithSameRequest() async {
        let fetcher = StoreAdDataFetcherSpy(impressionOutcomes: [
            .failure(AppError(statusCode: 503, message: "Unavailable")),
            .success
        ])
        let clock = ContinuousClock()
        let request = ImpressionReportRequest(impressionId: "impression-1", impressionToken: "token-1")
        let queue = withDependencies {
            $0[StoreAdDataFetcherKey.self] = fetcher
            $0.continuousClock = clock
        } operation: {
            StoreAdImpressionQueueClient()
        }

        await withDependencies {
            $0[StoreAdDataFetcherKey.self] = fetcher
            $0.continuousClock = clock
        } operation: {
            await queue.enqueue(request)
            await fetcher.waitForReportCount(2)
        }

        let reports = await fetcher.reportedImpressions
        #expect(reports.count == 2)
        #expect(reports.allSatisfy { $0.impressionId == request.impressionId })
        #expect(reports.allSatisfy { $0.impressionToken == request.impressionToken })
    }

    @Test("同一IDを重複送信せず複数IDも並列送信しない")
    func deduplicatesAndSerializesRequests() async throws {
        let fetcher = StoreAdDataFetcherSpy(reportDelay: .milliseconds(50))
        let first = ImpressionReportRequest(impressionId: "impression-1", impressionToken: "token-1")
        let second = ImpressionReportRequest(impressionId: "impression-2", impressionToken: "token-2")
        let queue = withDependencies {
            $0[StoreAdDataFetcherKey.self] = fetcher
        } operation: {
            StoreAdImpressionQueueClient()
        }

        await withDependencies {
            $0[StoreAdDataFetcherKey.self] = fetcher
        } operation: {
            await queue.enqueue(first)
            await queue.enqueue(second)
            await fetcher.waitForReportCount(2)
            await queue.enqueue(first)
        }
        try await Task.sleep(for: .milliseconds(150))

        let reports = await fetcher.reportedImpressions
        #expect(reports.map(\.impressionId) == [first.impressionId, second.impressionId])
        #expect(await fetcher.maximumConcurrentReports == 1)
    }

    @Test("再送可能なerrorだけを有限回再試行する")
    func retriesOnlyTransientErrorsAndStopsAtLimit() {
        #expect(StoreAdImpressionQueueClient.retryDelay(
            for: AppError(statusCode: 429, message: "Too Many Requests"),
            retryCount: 0
        ) == .seconds(1))
        #expect(StoreAdImpressionQueueClient.retryDelay(
            for: AppError(statusCode: 500, message: "Internal Server Error"),
            retryCount: 0
        ) == .seconds(1))
        #expect(StoreAdImpressionQueueClient.retryDelay(
            for: AppError.be(.network("offline")),
            retryCount: 1
        ) == .seconds(2))
        #expect(StoreAdImpressionQueueClient.retryDelay(
            for: AppError(statusCode: 401, message: "Unauthorized"),
            retryCount: 0
        ) == nil)
        #expect(StoreAdImpressionQueueClient.retryDelay(
            for: AppError(statusCode: 503, message: "Unavailable"),
            retryCount: 3
        ) == nil)
    }
}
