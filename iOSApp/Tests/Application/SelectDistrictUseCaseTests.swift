import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SelectDistrictUseCaseTests {
    @Test("地区選択はDataFetcherのレスポンスでAppStateを更新する")
    func 地区選択時に取得結果をAppStateへ反映する() async throws {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let currentPeriod = Period(
            id: "current-period",
            festivalId: festival.id,
            date: SimpleDate(year: 2026, month: 10, day: 3),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let route = Route(
            id: "current-route",
            districtId: district.id,
            periodId: currentPeriod.id,
            visibility: .admin
        )
        let oldRoute = Route(
            id: "old-route",
            districtId: district.id,
            periodId: "old-period",
            visibility: .admin
        )
        let previousPeriod = Period(
            id: "old-period",
            festivalId: festival.id,
            date: SimpleDate(year: 2025, month: 10, day: 3),
            start: SimpleTime(hour: 9, minute: 0),
            end: SimpleTime(hour: 17, minute: 0)
        )
        let point = Point(
            id: "point",
            routeId: oldRoute.id,
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let passage = RoutePassage(
            id: "passage",
            routeId: oldRoute.id,
            districtId: district.id,
            order: 0
        )
        let response = LaunchDistrictPack(
            performances: [],
            routes: [route, oldRoute],
            points: [point],
            passages: [passage],
            currentRouteId: oldRoute.id
        )
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                year: 2026,
                districts: [district],
                periods: [currentPeriod, previousPeriod],
                locations: [],
                checkpoints: [],
                hazardSections: []
            )
        ))
        let dataFetcher = SceneDataFetcherSpy(response: response)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = dataFetcher
            $0[UserDefaltsManagerKey.self] = DefaultUserDefaultsSpy()
        } operation: {
            SelectDistrictUseCase()
        }

        let selectedRouteId = try await useCase(districtId: district.id, appState: appState)

        #expect(selectedRouteId == oldRoute.id)
        #expect(await dataFetcher.districtLaunchCallCount() == 1)
        #expect(appState.wrappedValue?.districtState?.districtId == district.id)
        #expect(appState.wrappedValue?.districtState?.routes == [route, oldRoute])
        #expect(appState.wrappedValue?.festivalState.year == 2026)
        #expect(appState.wrappedValue?.period(id: previousPeriod.id) == previousPeriod)
        #expect(appState.wrappedValue?.routeState?.route == oldRoute)
        #expect(appState.wrappedValue?.routeState?.points == [point])
        #expect(appState.wrappedValue?.routeState?.passages == [passage])
    }
    @Test("地区選択解除は既定地区と画面の地区・ルート状態を消去する")
    func clearSelectedDistrict() async throws {
        let defaults = DefaultUserDefaultsSpy(festivalId: "festival", districtId: "district")
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [AppStateFixture.route()], currentRouteId: "route"
        ))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SelectDistrictUseCase() }

        let routeId = try await useCase(districtId: nil, appState: state)

        #expect(routeId == nil)
        #expect(defaults.defaultDistrictId == nil)
        #expect(state.wrappedValue?.districtState == nil)
        #expect(state.wrappedValue?.routeState == nil)
    }

    @Test("画面状態がない場合でも取得結果のルートIDと既定地区を保存する")
    func selectingDistrictWithoutAppState() async throws {
        let route = AppStateFixture.route()
        let pack = LaunchDistrictPack(
            performances: [], routes: [route], points: [],
            passages: [], currentRouteId: route.id
        )
        let fetcher = SceneDataFetcherSpy(response: pack)
        let defaults = DefaultUserDefaultsSpy()
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SelectDistrictUseCase() }

        let routeId = try await useCase(districtId: "district", appState: nil)

        #expect(routeId == "route")
        #expect(defaults.defaultDistrictId == "district")
        #expect(await fetcher.districtLaunchCallCount() == 1)
    }

    @Test("存在しない地区IDの読み込み結果は選択せず既定地区を変更しない")
    func rejectedDistrictDoesNotPersist() async throws {
        let pack = LaunchDistrictPack(
            performances: [], routes: [], points: [],
            passages: [], currentRouteId: nil
        )
        let fetcher = SceneDataFetcherSpy(response: pack)
        let defaults = DefaultUserDefaultsSpy(districtId: "old")
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = fetcher
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SelectDistrictUseCase() }

        let result = try await useCase(districtId: "missing", appState: state)

        #expect(result == nil)
        #expect(defaults.defaultDistrictId == "old")
        #expect(state.wrappedValue?.districtState == nil)
    }

    @Test("地区の読み込み失敗時には既定地区を更新せずエラーを返す")
    func failedDistrictLookupPropagatesError() async {
        let defaults = DefaultUserDefaultsSpy(districtId: "previous")
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[SceneDataFetcherKey.self] = MissingSceneDataFetcherSpy()
            $0[UserDefaltsManagerKey.self] = defaults
        } operation: { SelectDistrictUseCase() }

        await #expect(throws: AppError.self) {
            try await useCase(districtId: "district", appState: state)
        }
        #expect(defaults.defaultDistrictId == "previous")
    }

}
