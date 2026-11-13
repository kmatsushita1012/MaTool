import Dependencies
import Shared

extension DependencyValues {
    var storeAdBannerUsecase: any StoreAdBannerUsecaseProtocol {
        get { self[StoreAdBannerUsecaseKey.self] }
        set { self[StoreAdBannerUsecaseKey.self] = newValue }
    }
}

protocol StoreAdBannerUsecaseProtocol: Sendable {
    func nextBanner(festivalId: Festival.ID) async throws -> AdCandidate?
    func reportImpression(_ candidate: AdCandidate) async
}

struct StoreAdBannerUsecase: StoreAdBannerUsecaseProtocol {
    @Dependency(StoreAdDataFetcherKey.self) private var dataFetcher
    @Dependency(ImageCacheClientKey.self) private var imageCacheClient
    @Dependency(StoreAdImpressionQueueClientKey.self) private var impressionQueueClient

    func nextBanner(festivalId: Festival.ID) async throws -> AdCandidate? {
        guard let candidate = try await dataFetcher.nextBanner(festivalId: festivalId) else {
            return nil
        }
        try await imageCacheClient.preload(path: candidate.imagePath)
        return candidate
    }

    func reportImpression(_ candidate: AdCandidate) async {
        await impressionQueueClient.enqueue(
            ImpressionReportRequest(
                impressionId: candidate.impressionId,
                impressionToken: candidate.impressionToken
            )
        )
    }
}

enum StoreAdBannerUsecaseKey: DependencyKey {
    static let liveValue: any StoreAdBannerUsecaseProtocol = StoreAdBannerUsecase()
}
