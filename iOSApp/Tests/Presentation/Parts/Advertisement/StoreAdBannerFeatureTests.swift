import ComposableArchitecture
import Foundation
import Clocks
import Shared
import Testing
@testable import iOSApp

struct StoreAdBannerFeatureTests {
    @Test("画像が実際に表示されてからimpressionと5秒タイマーを開始する")
    @MainActor
    func startsImpressionAndDismissTimerAfterDisplay() async {
        let candidate = makeCandidate()
        let usecase = StoreAdBannerUsecaseSpy(candidate: candidate)
        let clock = TestClock()
        let store = TestStore(initialState: StoreAdBannerFeature.State(festivalId: candidate.festivalId)) {
            StoreAdBannerFeature()
        } withDependencies: {
            $0[StoreAdBannerUsecaseKey.self] = usecase
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        await store.send(.load) {
            $0.isLoading = true
        }
        await store.receive(.loadReceived(.success(candidate))) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.candidate = candidate
        }
        await store.send(.imageLoaded(candidate.impressionId)) {
            $0.isImageLoaded = true
        }

        await clock.advance(by: .seconds(5))
        #expect(!store.state.isDismissEnabled)
        #expect(await usecase.reportedImpressions.isEmpty)

        await store.send(.imageAppeared(candidate.impressionId)) {
            $0.isImageVisible = true
            $0.hasStartedDisplayingImage = true
        }
        await clock.advance(by: .seconds(5))
        await store.receive(.dismissButtonEnabled(candidate.impressionId)) {
            $0.isDismissEnabled = true
        }

        #expect(await usecase.reportedImpressions == [candidate])
        await store.finish()
    }

    @Test("古い候補の画像イベントは表示・impressionに反映しない")
    @MainActor
    func ignoresStaleImageEvents() async {
        let candidate = makeCandidate()
        let usecase = StoreAdBannerUsecaseSpy(candidate: candidate)
        let clock = TestClock()
        let store = TestStore(initialState: StoreAdBannerFeature.State(festivalId: candidate.festivalId)) {
            StoreAdBannerFeature()
        } withDependencies: {
            $0[StoreAdBannerUsecaseKey.self] = usecase
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        await store.send(.load) {
            $0.isLoading = true
        }
        await store.receive(.loadReceived(.success(candidate))) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.candidate = candidate
        }
        await store.send(.imageLoaded("stale-impression"))
        await store.send(.imageAppeared("stale-impression"))

        #expect(!store.state.isImageLoaded)
        #expect(!store.state.isImageVisible)
        #expect(await usecase.reportedImpressions.isEmpty)
        await store.finish()
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
