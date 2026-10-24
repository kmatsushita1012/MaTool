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
        let point = Point(
            id: "point",
            routeId: route.id,
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let passage = RoutePassage(
            id: "passage",
            routeId: route.id,
            districtId: district.id,
            order: 0
        )
        let response = LaunchDistrictPack(
            performances: [],
            routes: [route, oldRoute],
            points: [point],
            passages: [passage],
            currentRouteId: route.id
        )
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                districts: [district],
                periods: [currentPeriod],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        ))
        let dataFetcher = SceneDataFetcherSpy(response: response)
        let useCase = withDependencies {
            $0[SceneDataFetcherKey.self] = dataFetcher
            $0[UserDefaltsManagerKey.self] = EmptyUserDefaultsManager()
        } operation: {
            SelectDistrictUseCase()
        }

        let selectedRouteId = try await useCase(districtId: district.id, appState: appState)

        #expect(selectedRouteId == route.id)
        #expect(await dataFetcher.districtLaunchCallCount() == 1)
        #expect(appState.wrappedValue?.districtState?.districtId == district.id)
        #expect(appState.wrappedValue?.districtState?.routes == [route])
        #expect(appState.wrappedValue?.routeState?.route == route)
        #expect(appState.wrappedValue?.routeState?.points == [point])
        #expect(appState.wrappedValue?.routeState?.passages == [passage])
    }
}

private actor SceneDataFetcherSpy: SceneDataFetcherProtocol {
    private let response: LaunchDistrictPack
    private var districtLaunchCalls = 0

    init(response: LaunchDistrictPack) {
        self.response = response
    }

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        throw CancellationError()
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        throw CancellationError()
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        districtLaunchCalls += 1
        return response
    }

    func districtLaunchCallCount() -> Int {
        districtLaunchCalls
    }
}

private struct EmptyUserDefaultsManager: UserDefalutsManagerProtocol {
    var defaultFestivalId: String? { nil }
    var defaultDistrictId: String? { nil }
    var hasRequestedAlwaysLocationPermission: Bool { false }

    func saveDefaultFestivalId(_ value: String?) {}
    func saveDefaultDistrictId(_ value: String?) {}
    func saveHasRequestedAlwaysLocationPermission(_ value: Bool) {}
}
