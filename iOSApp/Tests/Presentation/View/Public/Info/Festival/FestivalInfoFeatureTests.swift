import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct FestivalInfoFeatureTests {
    @Test("FestivalInfoの切替状態を保持する")
    @MainActor
    func switchesBetweenFestivalAndDistrictList() async {
        let fixture = FestivalInfoFixture()
        let store = TestStore(initialState: fixture.makeState()) {
            FestivalInfoFeature()
        }

        await store.send(.binding(.set(\.displayMode, .districts))) {
            $0.displayMode = .districts
        }
        await store.send(.binding(.set(\.displayMode, .festival))) {
            $0.displayMode = .festival
        }
        await store.finish()
    }

    @Test("町紹介は画像の読み込み後にpushする")
    @MainActor
    func pushesDistrictAfterLoadingItsImage() async {
        let fixture = FestivalInfoFixture()
        let pack = DistrictPack(district: fixture.district, performances: [])
        let store = TestStore(initialState: fixture.makeState()) {
            FestivalInfoFeature()
        } withDependencies: {
            $0[FetchDistrictUseCaseKey.self] = StaticFetchDistrictUseCase(pack: pack)
            $0[ImageCacheClientKey.self] = NoopImageCacheClient()
        }

        await store.send(.districtSelected(fixture.district.id)) {
            $0.selectedDistrictID = fixture.district.id
            $0.isLoading = true
        }
        await store.receive(.districtReceived(.success(pack))) {
            $0.isLoading = false
            $0.destination = .district(
                DistrictInfoFeature.State(
                    pack,
                    appState: fixture.appState
                )
            )
        }
        await store.finish()
    }

    @Test("祭紹介の町一覧をGroup名、町名の順に並べる")
    func sortsDistrictsByGroupThenName() {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let districts = [
            District(id: "b2", name: "あ", festivalId: festival.id, group: "B"),
            District(id: "a2", name: "い", festivalId: festival.id, group: "A"),
            District(id: "a1", name: "あ", festivalId: festival.id, group: "A")
        ]
        let appState = Shared(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                districts: districts,
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        ))
        let state = FestivalInfoFeature.State(festival, appState: appState)

        #expect(state.districts.map(\.id) == ["a1", "a2", "b2"])
    }
}

private struct FestivalInfoFixture {
    let festival: Festival
    let district: District
    let appState: Shared<AppState?>

    init() {
        festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        district = District(id: "district", name: "District", festivalId: festival.id)
        appState = Shared(value: AppState(
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
    }

    func makeState() -> FestivalInfoFeature.State {
        FestivalInfoFeature.State(festival, appState: appState)
    }
}

private struct StaticFetchDistrictUseCase: FetchDistrictUseCaseProtocol {
    let pack: DistrictPack

    func callAsFunction(districtId: District.ID) async throws -> DistrictPack {
        pack
    }
}

private struct NoopImageCacheClient: ImageCacheClientProtocol {
    func preload(paths: [String?]) async {}
}
