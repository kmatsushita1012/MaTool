import ComposableArchitecture
import MapKit
import Shared
import Testing
@testable import iOSApp

struct PublicMapFeatureTests {
    @Test("地図の町PickerはDistrict.orderの昇順で並ぶ")
    func districtsAreSortedForMapPicker() {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let laterDistrict = District(id: "later", name: "Later", festivalId: festival.id, order: 2)
        let firstDistrict = District(id: "first", name: "First", festivalId: festival.id, order: 0)
        let middleDistrict = District(id: "middle", name: "Middle", festivalId: festival.id, order: 1)
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                districts: [laterDistrict, firstDistrict, middleDistrict],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        ))
        let state = PublicMapFeature.State(
            festival: festival,
            userRole: .guest,
            appState: appState
        )

        #expect(state.contents == [
            .locations,
            .route(firstDistrict.id),
            .route(middleDistrict.id),
            .route(laterDistrict.id)
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
            $0[LoadDistrictStateUseCaseKey.self] = loadUseCase
            $0[PublicMapAdUsecaseKey.self] = NoopPublicMapAdUsecase()
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
            year: 2026
        ))
    }
}

private actor DistrictLoadSpy: LoadDistrictStateUseCaseProtocol {
    private let response: LaunchDistrictPack
    private var periodId: Period.ID?

    init(response: LaunchDistrictPack) {
        self.response = response
    }

    func callAsFunction(
        districtId: District.ID,
        periodId: Period.ID?,
        appState: Shared<AppState?>
    ) async throws -> LaunchDistrictPack {
        self.periodId = periodId
        return response
    }

    func receivedPeriodId() -> Period.ID? {
        periodId
    }
}

private struct NoopPublicMapAdUsecase: PublicMapAdUsecaseProtocol {
    func prepareSession() async {}

    func handleDistrictSelectionResult(
        userRole: UserRole,
        districtId: District.ID,
        hasDisplayableContent: Bool
    ) async {}
}
