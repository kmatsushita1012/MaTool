import ComposableArchitecture
import Shared
import Testing
@testable import iOSApp

struct DistrictEditFeatureTests {
    @Test("地区編集はAppStateのPerformanceと祭典基準座標を使う")
    @MainActor
    func 地区基準が未設定でも祭典基準で地図を開く() async throws {
        let fixture = DistrictEditFixture()
        let initialState = try DistrictEditFeature.State(
            fixture.district,
            appState: fixture.appState
        )
        let store = TestStore(initialState: initialState) {
            DistrictEditFeature()
        }

        #expect(store.state.performances == [fixture.performance])

        await store.send(.baseTapped) {
            $0.destination = .base(.init(origin: fixture.festivalBase))
        }
        #expect(store.state.destination?.base?.region?.center.latitude == fixture.festivalBase.latitude)
        #expect(store.state.destination?.base?.region?.center.longitude == fixture.festivalBase.longitude)
        await store.finish()
    }

    @Test("地区範囲編集は地区基準が未設定なら祭典基準を使う")
    @MainActor
    func 地区範囲を祭典基準で開く() async throws {
        let fixture = DistrictEditFixture()
        let initialState = try DistrictEditFeature.State(
            fixture.district,
            appState: fixture.appState
        )
        let store = TestStore(initialState: initialState) {
            DistrictEditFeature()
        }

        await store.send(.areaTapped) {
            $0.destination = .area(
                .init(coordinates: fixture.district.area, origin: fixture.festivalBase)
            )
        }
        #expect(store.state.destination?.area?.region?.center.latitude == fixture.festivalBase.latitude)
        #expect(store.state.destination?.area?.region?.center.longitude == fixture.festivalBase.longitude)
        await store.finish()
    }

    @Test("地区詳細が未ロードなら空のPerformance一覧で編集を開始しない")
    @MainActor
    func 地区詳細未ロード時に編集状態を作らない() async {
        let fixture = DistrictEditFixture()
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: fixture.festivalPack,
            year: 2026
        ))
        let store = TestStore(
            initialState: DistrictDashboardFeature.State(fixture.district, appState: appState)
        ) {
            DistrictDashboardFeature()
        }

        await store.send(.onEdit) {
            $0.alert = .error("情報の取得に失敗しました")
        }
        #expect(store.state.destination == nil)
        await store.finish()
    }
}

private struct DistrictEditFixture {
    let festivalBase: Coordinate
    let festival: Festival
    let festivalPack: LaunchFestivalPack
    let district: District
    let performance: Performance
    let appState: Shared<AppState?>

    init() {
        let festivalBase = Coordinate(latitude: 35, longitude: 139)
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: festivalBase
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let performance = Performance(
            id: "performance",
            name: "Performance",
            districtId: district.id
        )
        let festivalPack = LaunchFestivalPack(
            festival: festival,
            districts: [district],
            periods: [],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
        self.festivalBase = festivalBase
        self.festival = festival
        self.district = district
        self.performance = performance
        self.festivalPack = festivalPack
        appState = Shared(value: AppState(
            festivalPack: festivalPack,
            districtPack: LaunchDistrictPack(
                performances: [performance],
                routes: [],
                points: [],
                passages: [],
                currentRouteId: nil
            ),
            districtId: district.id,
            year: 2026
        ))
    }
}
