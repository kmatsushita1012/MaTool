import ComposableArchitecture
import MapKit
import Shared
import Testing
@testable import iOSApp

struct PublicMapFeatureTests {
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
                districts: [laterGroupDistrict, selectedDistrict, sameGroupDistrict, firstGroupDistrict],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        ))
        var state = PublicMapFeature.State(
            festival: festival,
            userRole: .guest,
            appState: appState
        )

        #expect(state.contents == [
            .locations,
            .route(firstGroupDistrict.id),
            .route(sameGroupDistrict.id),
            .route(selectedDistrict.id),
            .route(laterGroupDistrict.id)
        ])

        state.selectedContent = .route(selectedDistrict.id)
        #expect(state.contents == [
            .locations,
            .route(selectedDistrict.id),
            .route(firstGroupDistrict.id),
            .route(sameGroupDistrict.id),
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
