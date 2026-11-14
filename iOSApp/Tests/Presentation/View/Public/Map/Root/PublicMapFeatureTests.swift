import ComposableArchitecture
import MapKit
import Shared
import Testing
@testable import iOSApp

struct PublicMapFeatureTests {
    @Test("メイン地図へのBinding通知では子画面が管理する共有表示領域を意図せず上書きしない")
    @MainActor
    func mapViewportBindingDoesNotOverwriteChildRegion() async {
        let initial = PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state())
        )
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.5, longitude: 138.5),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
        let store = TestStore(initialState: initial) {
            PublicMapFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        let original = store.state.mapRegion
        await store.send(.binding(.set(\.mapRegion, region)))
        #expect(store.state.mapRegion.center.latitude == original.center.latitude)
        #expect(store.state.mapRegion.center.longitude == original.center.longitude)
        await store.finish()
    }

    @Test("地図の町Pickerはgroup名、町名の順で並び、選択中の町と同じgroupを優先する")
    func districtsAreSortedForMapPicker() {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let selectedDistrict = District(id: "selected", name: "Zeta", festivalId: festival.id, group: "A")
        let sameGroupDistrict = District(id: "same-group", name: "Alpha", festivalId: festival.id, group: "A")
        let laterGroupDistrict = District(id: "later-group", name: "Alpha", festivalId: festival.id, group: "B")
        let firstGroupDistrict = District(id: "first-group", name: "Beta", festivalId: festival.id, group: "A")
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: [laterGroupDistrict, selectedDistrict, sameGroupDistrict, firstGroupDistrict],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
        ))
        var state = PublicMapFeature.State(
            festival: festival,
            userRole: .guest,
            appState: appState
        )

        #expect(state.contents == [
            .locations,
            .route(sameGroupDistrict.id),
            .route(firstGroupDistrict.id),
            .route(selectedDistrict.id),
            .route(laterGroupDistrict.id)
        ])

        state.selectedContent = .route(selectedDistrict.id)
        #expect(state.contents == [
            .locations,
            .route(selectedDistrict.id),
            .route(sameGroupDistrict.id),
            .route(firstGroupDistrict.id),
            .route(laterGroupDistrict.id)
        ])
    }

    @Test("町を切り替えても選択中の期間を引き継ぐ")
    @MainActor
    func changingDistrictRetainsSelectedPeriod() async {
        let fixture = PeriodSelectionFixture()
        let loadUseCase = DistrictLoadSpy(response: LaunchDistrictPack(
            performances: [],
            routes: [fixture.nextRoute],
            points: [],
            passages: [],
            currentRouteId: fixture.nextRoute.id
        ))
        let initialState = PublicMapFeature.State(
            festival: fixture.festival,
            district: fixture.currentDistrict,
            routeId: fixture.currentRoute.id,
            userRole: .guest,
            appState: fixture.appState
        )
        let store = TestStore(initialState: initialState) {
            PublicMapFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadDistrictStateUseCaseKey.self] = loadUseCase
            $0[PublicMapAdUsecaseKey.self] = PublicMapAdUsecaseSpy()
        }
        store.exhaustivity = .off

        await store.send(.contentSelected(.route(fixture.nextDistrict.id)))
        await store.receive(.districtLaunchReceived(.success(
            PublicMapFeature.DistrictLaunchResult(
                districtId: fixture.nextDistrict.id,
                routeId: fixture.nextRoute.id
            )
        )))

        #expect(await loadUseCase.receivedPeriodId() == fixture.period.id)
        await store.finish()
    }
    @Test("一覧と地区経路のコンテンツIDは一貫している")
    func contentIDsAreStable() {
        #expect(PublicMapFeature.Content.locations.id == "locations")
        #expect(PublicMapFeature.Content.route("district-1").id == "district-1")
        #expect(PublicMapFeature.Content.route("district-2").id == "district-2")
        #expect(PublicMapFeature.Content.route("district-1") != .route("district-2"))
    }

    @Test("地図のPicker表示名は祭典名・町名から生成される")
    func titlesComeFromFestivalAndDistrict() {
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        let state = PublicMapFeature.State(
            festival: AppStateFixture.festival(), userRole: .guest, appState: appState
        )

        #expect(state.festivalTitle == "Festival")
        #expect(state.contentTitles[.locations] == "現在地一覧")
        #expect(state.contentTitles[.route("district")] == "District")
    }

    @Test("町ごとのコンテンツグループには全ての町を重複せず含む")
    func districtGroupsPreserveDistrictContents() {
        let festival = AppStateFixture.festival()
        let districts = [
            District(id: "one", name: "A", festivalId: festival.id, group: "G"),
            District(id: "two", name: "B", festivalId: festival.id, group: "G"),
            District(id: "three", name: "C", festivalId: festival.id, group: "H")
        ]
        let appState = Shared<AppState?>(value: AppStateFixture.state(districts: districts))
        let state = PublicMapFeature.State(
            festival: festival, userRole: .guest, appState: appState
        )
        let grouped = state.districtContentGroups
        let ids = grouped.flatMap(\.contents).compactMap { content -> String? in
            guard case .route(let id) = content else { return nil }
            return id
        }

        #expect(ids.count == 3)
        #expect(Set(ids) == Set(["one", "two", "three"]))
        #expect(grouped.allSatisfy { !$0.contents.isEmpty })
        #expect(grouped.map(\.id).contains("G"))
        #expect(grouped.map(\.id).contains("H"))
    }

    @Test("地図の初回表示は位置権限と追跡を開始し広告セッションを準備する")
    @MainActor
    func onAppearStartsLocationAndAdSession() async {
        let location = MapLocationProviderSpy()
        let ad = PublicMapAdUsecaseSpy()
        let initial = PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state())
        )
        let store = TestStore(initialState: initial) {
            PublicMapFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0.mapLocationProvider = location
            $0[PublicMapAdUsecaseKey.self] = ad
        }

        await store.send(.onAppear)
        await store.finish()
        #expect(await location.permissionRequests == 1)
        #expect(await location.trackingStarts == 1)
        #expect(await ad.sessionPreparations == 1)
    }

    @Test("経路画面から現在地一覧に切り替えると子画面と選択状態を更新する")
    @MainActor
    func switchingToLocationsCreatesChildState() async {
        let festival = AppStateFixture.festival()
        var state = PublicMapFeature.State(
            festival: festival,
            district: AppStateFixture.district(),
            routeId: nil,
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state())
        )
        state.selectedContent = .route("district")
        let store = TestStore(initialState: state) {
            PublicMapFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.contentSelected(.locations))
        #expect(store.state.selectedContent == .locations)
        #expect(store.state.destination?.locations?.festivalId == festival.id)
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("存在しない町を選んでも読み込みは開始されない")
    @MainActor
    func selectingUnknownDistrictDoesNotLoad() async {
        let load = UnconfiguredLoadDistrictStateUseCaseSpy()
        let store = TestStore(initialState: PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state())
        )) {
            PublicMapFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadDistrictStateUseCaseKey.self] = load
        }
        store.exhaustivity = .off

        await store.send(.contentSelected(.route("missing-district")))
        #expect(store.state.selectedContent == .route("missing-district"))
        #expect(!store.state.isLoading)
        #expect((await load.requestedDistrictIDs).isEmpty)
        await store.finish()
    }

    @Test("町情報取得に失敗するとローディングを解除しエラーを地図へ表示する")
    @MainActor
    func districtLoadErrorShowsToast() async {
        var state = PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state())
        )
        state.isLoading = true
        let error = AppError.be(.network("offline"))
        let store = TestStore(initialState: state) {
            PublicMapFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.districtLaunchReceived(.failure(error)))
        #expect(!store.state.isLoading)
        #expect(store.state.toast != nil)
        await store.finish()
    }

    @Test("読み込み成功で既存の町の経路画面を開き広告判定に表示可否を伝える")
    @MainActor
    func routePreparationCreatesRouteAndNotifiesAdPolicy() async {
        let ad = PublicMapAdUsecaseSpy()
        var state = PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state(routes: [AppStateFixture.route()]))
        )
        state.isLoading = true
        let store = TestStore(initialState: state) {
            PublicMapFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PublicMapAdUsecaseKey.self] = ad
        }
        store.exhaustivity = .off

        await store.send(.routePrepared("district", "route"))
        await store.receive(.districtContentEvaluated(AppStateFixture.district(), true))
        #expect(!store.state.isLoading)
        #expect(store.state.destination?.route?.districtId == "district")
        await store.finish()
        #expect(await ad.selections.count == 1)
        #expect(await ad.selections.first?.districtId == "district")
        #expect(await ad.selections.first?.hasDisplayableContent == true)
    }

    @Test("取得済みレスポンスの町が消えていたら不在エラーを表示する")
    @MainActor
    func removedDistrictReturnsNotFoundError() async {
        var state = PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state())
        )
        state.isLoading = true
        let store = TestStore(initialState: state) {
            PublicMapFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.routePrepared("removed-district", nil))
        await store.receive(.errorCaught(.be(.notFound("地区が見つかりません。"))))
        #expect(!store.state.isLoading)
        #expect(store.state.toast != nil)
        await store.finish()
    }

    @Test("地区に公開コンテンツがない場合も広告判定にその事実を伝える")
    @MainActor
    func emptyContentStillNotifiesAdPolicy() async {
        let ad = PublicMapAdUsecaseSpy()
        let store = TestStore(initialState: PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state())
        )) {
            PublicMapFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PublicMapAdUsecaseKey.self] = ad
        }
        store.exhaustivity = .off

        await store.send(.districtContentEvaluated(AppStateFixture.district(), false))
        await store.finish()
        #expect(await ad.selections.count == 1)
        #expect(await ad.selections.first?.hasDisplayableContent == false)
    }

    @Test("地図の表示エラーは別の操作を妨げずToastに保持される")
    @MainActor
    func displayErrorOnlyUpdatesToast() async {
        let store = TestStore(initialState: PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state())
        )) {
            PublicMapFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.errorCaught(.be(.network("offline"))))
        #expect(store.state.selectedContent == .locations)
        #expect(store.state.toast != nil)
        await store.finish()
    }

    @Test("読み込み済みの町を表示するときは地区を二重取得せず位置追跡だけ開始する")
    @MainActor
    func routeOnAppearDoesNotReloadLoadedDistrict() async {
        let fixture = PeriodSelectionFixture()
        let load = UnconfiguredLoadDistrictStateUseCaseSpy()
        let location = MapLocationProviderSpy()
        let ad = PublicMapAdUsecaseSpy()
        let initial = PublicMapFeature.State(
            festival: fixture.festival,
            district: fixture.currentDistrict,
            routeId: fixture.currentRoute.id,
            userRole: .guest,
            appState: fixture.appState
        )
        let store = TestStore(initialState: initial) {
            PublicMapFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadDistrictStateUseCaseKey.self] = load
            $0.mapLocationProvider = location
            $0[PublicMapAdUsecaseKey.self] = ad
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.finish()

        #expect(store.state.destination?.route?.selectedRouteId == fixture.currentRoute.id)
        #expect(!store.state.isLoading)
        #expect((await load.requestedDistrictIDs).isEmpty)
        #expect(await location.permissionRequests == 1)
        #expect(await location.trackingStarts == 1)
        #expect(await ad.sessionPreparations == 1)
    }

    @Test("初期表示の町が未読込なら開催期間外でも読み込みを開始する")
    @MainActor
    func routeOnAppearLoadsNewDistrictWithCurrentPeriod() async {
        let fixture = PeriodSelectionFixture()
        let load = DistrictLoadSpy(response: LaunchDistrictPack(
            performances: [],
            routes: [fixture.nextRoute],
            points: [],
            passages: [],
            currentRouteId: fixture.nextRoute.id
        ))
        let initial = PublicMapFeature.State(
            festival: fixture.festival,
            district: fixture.nextDistrict,
            routeId: nil,
            userRole: .guest,
            appState: fixture.appState
        )
        let store = TestStore(initialState: initial) {
            PublicMapFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[LoadDistrictStateUseCaseKey.self] = load
            $0[PublicMapAdUsecaseKey.self] = PublicMapAdUsecaseSpy()
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(.districtLaunchReceived(.success(
            .init(districtId: fixture.nextDistrict.id, routeId: fixture.nextRoute.id)
        )))
        #expect(await load.receivedPeriodId() == nil)
        await store.finish()
    }

    @Test("AppStateがない場合は祭典名・町名・期間を空の安全な状態として扱う")
    func absentAppStateUsesSafeFallbackMapContents() {
        let state = PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: Shared<AppState?>(value: nil)
        )
        #expect(state.contents == [.locations])
        #expect(state.districtContentGroups.isEmpty)
        #expect(state.festivalTitle == "")
        #expect(state.currentPeriodId == nil)
        #expect(state.selectedPeriodId == nil)
        #expect(state.contentTitles == [.locations: "現在地一覧"])
    }

    @Test("AppState消失後の現在地選択は不完全な子画面を再構築しない")
    @MainActor
    func locationsSelectionWithoutSessionDoesNotRecreateChild() async {
        let appState = Shared<AppState?>(value: AppStateFixture.state())
        var initial = PublicMapFeature.State(
            festival: AppStateFixture.festival(),
            userRole: .guest,
            appState: appState
        )
        initial.selectedContent = .route("district")
        appState.withLock { $0 = nil }
        let store = TestStore(initialState: initial) {
            PublicMapFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.contentSelected(.locations))
        #expect(store.state.selectedContent == .locations)
        #expect(store.state.destination?.locations?.festivalId == "festival")
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("空白だけの地区グループは名前なしの同一グループにまとめる")
    func blankGroupNamesAreTreatedAsUngrouped() {
        let festival = AppStateFixture.festival()
        let districts = [
            District(id: "without", name: "A", festivalId: festival.id),
            District(id: "blank", name: "B", festivalId: festival.id, group: "  \t  ")
        ]
        let state = PublicMapFeature.State(
            festival: festival,
            userRole: .guest,
            appState: Shared(value: AppStateFixture.state(districts: districts))
        )
        #expect(state.districtContentGroups.count == 1)
        #expect(state.districtContentGroups.first?.name == nil)
        #expect(Set(state.districtContentGroups.flatMap(\.contents)) == Set([
            .route("without"), .route("blank")
        ]))
    }

}

private struct PeriodSelectionFixture {
    let festival: Festival
    let currentDistrict: District
    let nextDistrict: District
    let period: Period
    let currentRoute: Route
    let nextRoute: Route
    let appState: Shared<AppState?>

    init() {
        festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        currentDistrict = District(id: "current", name: "Current", festivalId: festival.id)
        nextDistrict = District(id: "next", name: "Next", festivalId: festival.id)
        period = Period(
            id: "period",
            festivalId: festival.id,
            title: "Night",
            date: SimpleDate(year: 2026, month: 10, day: 3),
            start: SimpleTime(hour: 18, minute: 0),
            end: SimpleTime(hour: 20, minute: 0)
        )
        currentRoute = Route(id: "current-route", districtId: currentDistrict.id, periodId: period.id)
        nextRoute = Route(id: "next-route", districtId: nextDistrict.id, periodId: period.id)
        appState = Shared(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                districts: [currentDistrict, nextDistrict],
                periods: [period],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            districtPack: LaunchDistrictPack(
                performances: [],
                routes: [currentRoute],
                points: [],
                passages: [],
                currentRouteId: currentRoute.id
            ),
            districtId: currentDistrict.id,
        ))
    }
}
