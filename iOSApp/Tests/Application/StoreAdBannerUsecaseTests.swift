import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct StoreAdBannerUsecaseTests {
    @Test("候補画像のプリロード完了後に表示候補を返す")
    func preloadsBannerBeforeReturningCandidate() async throws {
        let candidate = makeCandidate()
        let fetcher = StoreAdDataFetcherSpy(candidate: candidate)
        let imageCache = ImageCacheClientSpy()

        let result = try await withDependencies {
            $0[StoreAdDataFetcherKey.self] = fetcher
            $0[ImageCacheClientKey.self] = imageCache
        } operation: {
            try await StoreAdBannerUsecase().nextBanner(festivalId: candidate.festivalId)
        }

        #expect(result == candidate)
        #expect(await fetcher.requestedFestivalIDs == [candidate.festivalId])
        #expect(await imageCache.preloadedPaths == [candidate.imagePath])
    }

    @Test("画像プリロード失敗時は候補を返さない")
    func doesNotReturnCandidateWhenPreloadFails() async {
        let candidate = makeCandidate()
        let fetcher = StoreAdDataFetcherSpy(candidate: candidate)
        let imageCache = ImageCacheClientSpy(failsSinglePathPreload: true)

        await #expect(throws: ImageCacheClientError.invalidURL) {
            try await withDependencies {
                $0[StoreAdDataFetcherKey.self] = fetcher
                $0[ImageCacheClientKey.self] = imageCache
            } operation: {
                try await StoreAdBannerUsecase().nextBanner(festivalId: candidate.festivalId)
            }
        }
        #expect(await imageCache.preloadedPaths == [candidate.imagePath])
    }

    @Test("impressionを共有キューへ同じIDとtokenで渡す")
    func queuesOriginalImpressionRequest() async {
        let candidate = makeCandidate()
        let queue = StoreAdImpressionQueueClientSpy()

        await withDependencies {
            $0[StoreAdImpressionQueueClientKey.self] = queue
        } operation: {
            await StoreAdBannerUsecase().reportImpression(candidate)
        }

        let requests = await queue.requests
        #expect(requests.count == 1)
        #expect(requests.first?.impressionId == candidate.impressionId)
        #expect(requests.first?.impressionToken == candidate.impressionToken)
    }
}

private func makeCandidate() -> AdCandidate {
    AdCandidate(
        storeId: "store",
        festivalId: "festival",
        placement: .banner,
        imagePath: "https://images.example/banner.jpg",
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        impressionId: "impression",
        impressionToken: "token"
    )
}
