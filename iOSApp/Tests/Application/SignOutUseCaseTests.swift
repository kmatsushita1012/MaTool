import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct SignOutUseCaseTests {
    @Test("ログアウト成功時に管理者向け地区・経路状態を破棄する")
    func clearsAdminStateAfterSuccessfulAuthenticationRemoval() async throws {
        let fixture = SignOutFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var authProvider = AuthProviderSpy().client
        authProvider.signOut = {}
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = authProvider
        } operation: {
            SignOutUseCase()
        }

        try await useCase(appState: appState)

        let clearedState = try #require(appState.wrappedValue)
        #expect(clearedState.festivalState.festival == fixture.appState.festivalState.festival)
        #expect(clearedState.festivalState.districts == fixture.appState.festivalState.districts)
        #expect(clearedState.festivalState.periods == fixture.appState.festivalState.periods)
        #expect(clearedState.festivalState.floatLocations == fixture.appState.festivalState.floatLocations)
        #expect(clearedState.festivalState.checkpoints.isEmpty)
        #expect(clearedState.festivalState.hazardSections.isEmpty)
        #expect(clearedState.districtState == nil)
        #expect(clearedState.routeState == nil)
        #expect(clearedState.districtLoadRequestId != fixture.appState.districtLoadRequestId)
        #expect(clearedState.routeLoadRequestId != fixture.appState.routeLoadRequestId)
    }

    @Test("ログアウト失敗時はAppStateを変更しない")
    func preservesAppStateWhenAuthenticationRemovalFails() async throws {
        let fixture = SignOutFixture()
        let appState = Shared<AppState?>(value: fixture.appState)
        var authProvider = AuthProviderSpy().client
        authProvider.signOut = { throw SignOutFixtureError.failed }
        let useCase = withDependencies {
            $0.installTestSpies()
            $0.authProvider = authProvider
        } operation: {
            SignOutUseCase()
        }

        await #expect(throws: SignOutFixtureError.failed) {
            try await useCase(appState: appState)
        }

        #expect(appState.wrappedValue == fixture.appState)
    }
}

private struct SignOutFixture {
    let appState: AppState

    init() {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let period = Period(id: "period", festivalId: festival.id, date: .now)
        let route = Route(id: "route", districtId: district.id, periodId: period.id)
        let point = Point(id: "point", routeId: route.id, coordinate: festival.base)
        let festivalState = FestivalState(
            LaunchFestivalPack(
                festival: festival,
                districts: [district],
                periods: [period],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: Calendar.current.component(.year, from: .now)
        )
        let districtState = DistrictState(
            districtId: district.id,
            pack: LaunchDistrictPack(
                performances: [],
                routes: [route],
                points: [point],
                passages: [],
                currentRouteId: route.id
            ),
            currentPeriodIds: Set(festivalState.periods.map(\.id))
        )
        appState = AppState(
            festivalState: festivalState,
            districtState: districtState,
            routeState: RouteState(route: route, points: [point], passages: [])
        )
    }
}

private enum SignOutFixtureError: Error {
    case failed
}
