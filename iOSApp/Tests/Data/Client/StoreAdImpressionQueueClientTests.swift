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

    @Test("再試行を使い切ったimpressionは次のenqueueで古いものから再送する")
    func retainsFailedRequestUntilNextEnqueue() async {
        let fetcher = StoreAdDataFetcherSpy(impressionOutcomes: [
            .failure(AppError(statusCode: 503, message: "Unavailable")),
            .failure(AppError(statusCode: 503, message: "Unavailable")),
            .failure(AppError(statusCode: 503, message: "Unavailable")),
            .failure(AppError(statusCode: 503, message: "Unavailable")),
            .success,
            .success
        ])
        let clock = ContinuousClock()
        let first = ImpressionReportRequest(impressionId: "impression-1", impressionToken: "token-1")
        let second = ImpressionReportRequest(impressionId: "impression-2", impressionToken: "token-2")
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
            await queue.enqueue(first)
            await fetcher.waitForReportCount(1)
            await fetcher.waitForReportCount(2)
            await fetcher.waitForReportCount(3)
            await fetcher.waitForReportCount(4)
            #expect(await fetcher.reportCount() == 4)

            await queue.enqueue(second)
            await fetcher.waitForReportCount(6)
        }

        let reports = await fetcher.reportedImpressions
        #expect(reports.map(\.impressionId) == [
            first.impressionId,
            first.impressionId,
            first.impressionId,
            first.impressionId,
            first.impressionId,
            second.impressionId
        ])
        #expect(reports[4].impressionToken == first.impressionToken)
        #expect(reports[5].impressionToken == second.impressionToken)
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

    @Test("恒久的なクライアントエラーは破棄し、後続のimpressionを送信する")
    func dropsPermanentFailureAndContinuesWithNextRequest() async {
        let fetcher = StoreAdDataFetcherSpy(impressionOutcomes: [
            .failure(AppError(statusCode: 400, message: "Invalid token")),
            .success
        ])
        let first = ImpressionReportRequest(impressionId: "impression-invalid", impressionToken: "expired-token")
        let second = ImpressionReportRequest(impressionId: "impression-next", impressionToken: "valid-token")
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
        }

        let reports = await fetcher.reportedImpressions
        #expect(reports.map(\.impressionId) == [first.impressionId, second.impressionId])
    }

    @Test("再送可能なerrorだけを有限回再試行する")
    func retriesOnlyTransientErrorsAndStopsAtLimit() {
        #expect(StoreAdImpressionQueueClient.isRetryable(AppError(statusCode: 429, message: "Too Many Requests")))
        #expect(StoreAdImpressionQueueClient.isRetryable(AppError(statusCode: 500, message: "Internal Server Error")))
        #expect(StoreAdImpressionQueueClient.isRetryable(AppError.be(.network("offline"))))
        #expect(StoreAdImpressionQueueClient.isRetryable(AppError.be(.timeout("request timed out"))))
        #expect(StoreAdImpressionQueueClient.isRetryable(AppError(statusCode: 408, message: "Request Timeout")))
        #expect(!StoreAdImpressionQueueClient.isRetryable(AppError(statusCode: 401, message: "Unauthorized")))
        #expect(!StoreAdImpressionQueueClient.isRetryable(AppError(statusCode: 404, message: "Not Found")))
        #expect(StoreAdImpressionQueueClient.retryDelay(consecutiveFailureCount: 1) == .seconds(1))
        #expect(StoreAdImpressionQueueClient.retryDelay(consecutiveFailureCount: 2) == .seconds(2))
        #expect(StoreAdImpressionQueueClient.retryDelay(consecutiveFailureCount: 3) == .seconds(4))
        #expect(StoreAdImpressionQueueClient.retryDelay(consecutiveFailureCount: 4) == .seconds(8))
        #expect(StoreAdImpressionQueueClient.retryDelay(consecutiveFailureCount: 100) == .seconds(60))
    }
}
