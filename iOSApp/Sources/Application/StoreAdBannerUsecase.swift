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
    func reportImpression(_ candidate: AdCandidate) async throws
}

struct StoreAdBannerUsecase: StoreAdBannerUsecaseProtocol {
    @Dependency(StoreAdDataFetcherKey.self) private var dataFetcher

    func nextBanner(festivalId: Festival.ID) async throws -> AdCandidate? {
        try await dataFetcher.nextBanner(festivalId: festivalId)
    }

    func reportImpression(_ candidate: AdCandidate) async throws {
        try await dataFetcher.reportImpression(
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
