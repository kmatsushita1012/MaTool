import ComposableArchitecture
import Shared
import Testing
import SwiftUI
@testable import iOSApp

struct FestivalInfoFeatureTests {
    @Test("外観の自動判定は初回のみ適用され手動選択が優先される")
    @MainActor
    func colorThemeSelectionOverridesInitialResolution() async {
        let fixture = FestivalInfoFixture()
        let store = TestStore(initialState: fixture.makeState()) {
            FestivalInfoFeature()
        } withDependencies: { $0.installTestSpies() }
        await store.send(.colorThemeResolved(.dark)) { $0.colorTheme = .dark }
        await store.send(.colorThemeResolved(.light))
        await store.send(.colorThemeSelected(.light)) { $0.colorTheme = .light }
        await store.finish()
    }

    @Test("FestivalInfoの切替状態を保持する")
    @MainActor
    func switchesBetweenFestivalAndDistrictList() async {
        let fixture = FestivalInfoFixture()
        let store = TestStore(initialState: fixture.makeState()) {
            FestivalInfoFeature()
        } withDependencies: {
            $0.installTestSpies()
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
            $0.installTestSpies()
            $0[FetchDistrictUseCaseKey.self] = FetchDistrictUseCaseSpy(pack: pack)
            $0[ImageCacheClientKey.self] = ImageCacheClientSpy()
        }

        await store.send(.districtSelected(fixture.district.id)) {
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
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: districts,
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
        ))
        let state = FestivalInfoFeature.State(festival, appState: appState)

        #expect(state.districts.map(\.id) == ["a1", "a2", "b2"])
    }
    @Test("存在しない町の選択は取得処理を始めず、エラーを表示する")
    @MainActor
    func unknownDistrictShowsAlertWithoutFetching() async {
        let fixture = FestivalInfoFixture()
        let spy = FetchDistrictUseCaseSpy()
        let store = TestStore(initialState: fixture.makeState()) {
            FestivalInfoFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchDistrictUseCaseKey.self] = spy
        }

        await store.send(.districtSelected("missing-district")) {
            $0.alert = .error("町の紹介を表示できませんでした")
        }
        #expect(await spy.requestedIDs.isEmpty)
        await store.send(.alert(.dismiss)) { $0.alert = nil }
        await store.finish()
    }

    @Test("町の紹介取得に失敗するとローディングを解除し、原因を表示する")
    @MainActor
    func districtFetchErrorClearsLoadingAndShowsReason() async {
        let fixture = FestivalInfoFixture()
        let error = AppError.be(.network("offline"))
        let store = TestStore(initialState: fixture.makeState()) {
            FestivalInfoFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[FetchDistrictUseCaseKey.self] = FailingFestivalInfoDistrictSpy(error: error)
        }

        await store.send(.districtSelected(fixture.district.id)) { $0.isLoading = true }
        await store.receive(.districtReceived(.failure(error))) {
            $0.isLoading = false
            $0.alert = .error(error.message)
        }
        await store.finish()
    }

    @Test("同じGroup名と町名の町はID順に安定して並べる")
    func tiesInDistrictNamesSortByID() {
        let fixture = FestivalInfoFixture()
        let festival = fixture.festival
        let state = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: [
                    District(id: "z", name: "同名", festivalId: festival.id, group: "A"),
                    District(id: "a", name: "同名", festivalId: festival.id, group: "A")
                ],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            )
        ))
        let subject = FestivalInfoFeature.State(festival, appState: state)
        #expect(subject.districts.map(\.id) == ["a", "z"])
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
                year: 2026,
                districts: [district],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
        ))
    }

    func makeState() -> FestivalInfoFeature.State {
        FestivalInfoFeature.State(festival, appState: appState)
    }
}

private struct FailingFestivalInfoDistrictSpy: FetchDistrictUseCaseProtocol {
    let error: AppError

    func callAsFunction(districtId: District.ID) async throws -> DistrictPack {
        throw error
    }
}
