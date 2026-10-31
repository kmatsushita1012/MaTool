import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct DistrictIntroductionRootFeatureTests {
    @Test("町紹介から祭紹介へ画像読み込み後にpushする")
    @MainActor
    func pushesFestivalAfterLoadingItsImage() async {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                districts: [district],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        ))
        let pack = DistrictPack(district: district, performances: [])
        let initialState = DistrictIntroductionRootFeature.State(
            pack,
            festival: festival,
            appState: appState
        )
        let store = TestStore(initialState: initialState) {
            DistrictIntroductionRootFeature()
        } withDependencies: {
            $0[ImageCacheClientKey.self] = NoopImageCacheClient()
        }

        await store.send(.festivalTapped) {
            $0.isLoading = true
        }
        await store.receive(.festivalImagePreloaded) {
            $0.isLoading = false
            $0.destination = .festival(FestivalInfoFeature.State(
                festival,
                appState: appState
            ))
        }
        await store.finish()
    }
}

private struct NoopImageCacheClient: ImageCacheClientProtocol {
    func preload(paths: [String?]) async {}
}
