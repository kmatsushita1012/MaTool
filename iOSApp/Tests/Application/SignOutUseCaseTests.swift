import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct SignOutUseCaseTests {
    @Test("ログアウト成功時は保存済み選択からBE情報を再取得して新しいAppStateを構築する")
    func rebuildsAppStateFromSelectedFestivalAndDistrict() async throws {
        let fixture = SignOutFixture()
        let appState = Shared<AppState?>(value: fixture.oldAppState)
        let userDefaults = DefaultUserDefaultsSpy(
            festivalId: fixture.festival.id,
            districtId: fixture.district.id
        )
        let dataFetcher = SignOutSceneDataFetcherSpy(
            festivalPack: fixture.festivalPack,
            districtPack: fixture.districtPack
        )
        let sessionCoordinator = SceneSessionCoordinatorSpy()
        let initializeSpy = AuthProviderInitializeSpy()
        var authProvider = AuthProviderSpy().client
        authProvider.initialize = { initializeSpy.record() }
        authProvider.signOut = {}
        let launchState = try await withDependencies {
            $0.installTestSpies()
            $0.authProvider = authProvider
            $0[UserDefaltsManagerKey.self] = userDefaults
            $0[SceneDataFetcherKey.self] = dataFetcher
            $0[SceneSessionCoordinatorKey.self] = sessionCoordinator
        } operation: {
            try await SignOutUseCase()(appState: appState)
        }

        let rebuiltState = try #require(appState.wrappedValue)
        #expect(launchState == .district(.guest, fixture.route.id))
        #expect(initializeSpy.callCount == 0)
        #expect(Set(await dataFetcher.requests) == Set([
            "festival:\(fixture.festival.id)",
            "district:\(fixture.district.id):period:nil"
        ]))
        #expect(await sessionCoordinator.sessionStarts == 1)
        #expect(rebuiltState.sessionId != fixture.oldAppState.sessionId)
        #expect(rebuiltState.districtLoadRequestId != fixture.oldAppState.districtLoadRequestId)
        #expect(rebuiltState.routeLoadRequestId != fixture.oldAppState.routeLoadRequestId)
        #expect(rebuiltState.festivalState == FestivalState(fixture.festivalPack))
        #expect(rebuiltState.districtState?.districtId == fixture.district.id)
        #expect(rebuiltState.districtState?.routes == [fixture.route])
        #expect(rebuiltState.routeState?.route == fixture.route)
        #expect(rebuiltState.routeState?.points == [fixture.point])
        #expect(rebuiltState.festivalState.festival.name == "取得し直した祭典")
        #expect(rebuiltState.festivalState.checkpoints == fixture.festivalPack.checkpoints)
        #expect(rebuiltState.festivalState.hazardSections == fixture.festivalPack.hazardSections)
    }

    @Test("BE設定取得失敗時は旧AppStateを残さずエラー画面状態を返す")
    func clearsOldAppStateWhenLaunchDataFetchFails() async throws {
        let fixture = SignOutFixture()
        let appState = Shared<AppState?>(value: fixture.oldAppState)
        let userDefaults = DefaultUserDefaultsSpy(
            festivalId: fixture.festival.id,
            districtId: fixture.district.id
        )
        let dataFetcher = SignOutSceneDataFetcherSpy(
            festivalPack: fixture.festivalPack,
            districtPack: fixture.districtPack,
            failsDistrictLaunch: true
        )
        let initializeSpy = AuthProviderInitializeSpy()
        var authProvider = AuthProviderSpy().client
        authProvider.initialize = { initializeSpy.record() }
        authProvider.signOut = {}
        let launchState = try await withDependencies {
            $0.installTestSpies()
            $0.authProvider = authProvider
            $0[UserDefaltsManagerKey.self] = userDefaults
            $0[SceneDataFetcherKey.self] = dataFetcher
        } operation: {
            try await SignOutUseCase()(appState: appState)
        }

        #expect(isError(launchState))
        #expect(initializeSpy.callCount == 0)
        #expect(appState.wrappedValue == nil)
        #expect(Set(await dataFetcher.requests) == Set([
            "festival:\(fixture.festival.id)",
            "district:\(fixture.district.id):period:nil"
        ]))
    }

    @Test("認証ログアウト失敗時はAppStateを変更せずBEを呼ばない")
    func preservesAppStateWhenAuthenticationRemovalFails() async throws {
        let fixture = SignOutFixture()
        let appState = Shared<AppState?>(value: fixture.oldAppState)
        let dataFetcher = SignOutSceneDataFetcherSpy(
            festivalPack: fixture.festivalPack,
            districtPack: fixture.districtPack
        )
        let initializeSpy = AuthProviderInitializeSpy()
        var authProvider = AuthProviderSpy().client
        authProvider.initialize = { initializeSpy.record() }
        authProvider.signOut = { throw SignOutFixtureError.failed }
        await #expect(throws: SignOutFixtureError.failed) {
            try await withDependencies {
            $0.installTestSpies()
            $0.authProvider = authProvider
            $0[SceneDataFetcherKey.self] = dataFetcher
            } operation: {
                try await SignOutUseCase()(appState: appState)
            }
        }

        #expect(appState.wrappedValue == fixture.oldAppState)
        #expect(initializeSpy.callCount == 0)
        #expect(await dataFetcher.requests.isEmpty)
    }

    private func isError(_ launchState: LaunchState) -> Bool {
        if case .error = launchState { return true }
        return false
    }
}

private struct SignOutFixture {
    let festival: Festival
    let district: District
    let route: Route
    let point: Point
    let festivalPack: LaunchFestivalPack
    let districtPack: LaunchDistrictPack
    let oldAppState: AppState

    init() {
        festival = Festival(
            id: "selected-festival",
            name: "取得し直した祭典",
            subname: "Fresh Festival",
            base: Coordinate(latitude: 35.1, longitude: 139.1)
        )
        district = District(id: "selected-district", name: "取得し直した町", festivalId: festival.id)
        let period = Period(id: "selected-period", festivalId: festival.id, date: .now)
        route = Route(id: "new-route", districtId: district.id, periodId: period.id)
        point = Point(id: "new-point", routeId: route.id, coordinate: festival.base)
        festivalPack = LaunchFestivalPack(
            festival: festival,
            districts: [district],
            periods: [period],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
        districtPack = LaunchDistrictPack(
            performances: [],
            routes: [route],
            points: [point],
            passages: [],
            currentRouteId: route.id
        )

        let staleFestival = Festival(
            id: "old-festival",
            name: "古い祭典",
            subname: "Old Festival",
            base: Coordinate(latitude: 36, longitude: 140)
        )
        let staleDistrict = District(id: "old-district", name: "古い町", festivalId: staleFestival.id)
        let stalePeriod = Period(id: "old-period", festivalId: staleFestival.id, date: .now)
        let staleRoute = Route(id: "old-route", districtId: staleDistrict.id, periodId: stalePeriod.id)
        let stalePoint = Point(id: "old-point", routeId: staleRoute.id, coordinate: staleFestival.base)
        let staleFestivalState = FestivalState(
            LaunchFestivalPack(
                festival: staleFestival,
                districts: [staleDistrict],
                periods: [stalePeriod],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
        )
        oldAppState = AppState(
            festivalState: staleFestivalState,
            districtState: DistrictState(
                districtId: staleDistrict.id,
                pack: LaunchDistrictPack(
                    performances: [],
                    routes: [staleRoute],
                    points: [stalePoint],
                    passages: [],
                    currentRouteId: staleRoute.id
                )
            ),
            routeState: RouteState(route: staleRoute, points: [stalePoint], passages: [])
        )
    }
}

private enum SignOutFixtureError: Error {
    case failed
}
