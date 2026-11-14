import Foundation
import Shared
import Testing
@testable import iOSApp

extension AppStateTests {
    @Test("ID検索と選択地区・選択ルートは一致したデータのみを返す")
    func resolvesOnlyMatchingEntries() {
        let period = AppStateFixture.period()
        let route = AppStateFixture.route()
        let state = AppStateFixture.state(
            periods: [period], routes: [route], currentRouteId: route.id
        )

        #expect(state.district(id: "district")?.id == "district")
        #expect(state.district(id: "unknown") == nil)
        #expect(state.selectedDistrict?.id == "district")
        #expect(state.period(id: "period") == period)
        #expect(state.period(id: "unknown") == nil)
        #expect(state.routeState(for: route.id)?.route == route)
        #expect(state.routeState(for: nil) == nil)
        #expect(state.routeState(for: "unrelated") == nil)
        #expect(state.checkpoint(id: nil) == nil)
        #expect(state.checkpoint(id: "unknown") == nil)
        #expect(state.performance(id: nil, districtId: "district") == nil)
        #expect(state.performance(id: "missing", districtId: "wrong") == nil)
        #expect(state.floatLocation(for: "missing") == nil)
        #expect(state.floatEntry(for: "missing") == nil)
        #expect(state.currentPeriod(at: Date(timeIntervalSince1970: 0)) == nil)
    }

    @Test("District未選択時は選択状態とRoute/Point一覧を返さない")
    func missingDistrictReturnsNoSelections() {
        let state = AppStateFixture.state(selectedDistrictId: nil)
        #expect(state.selectedDistrict == nil)
        #expect(state.routeEntries(for: "district").isEmpty)
        #expect(state.routeEntry(id: "route", districtId: "district") == nil)
        #expect(state.pointEntries(for: "route", districtId: "district").isEmpty)
    }

    @Test("RouteEntryは所属地区と存在する期間で解決する")
    func routeEntriesRequireKnownPeriodAndDistrict() {
        let valid = AppStateFixture.route(id: "valid")
        let missingPeriod = AppStateFixture.route(id: "orphan", periodId: "absent")
        let state = AppStateFixture.state(
            routes: [missingPeriod, valid], currentRouteId: valid.id
        )

        #expect(state.routeEntries(for: "district").map(\.route.id) == ["valid"])
        #expect(state.routeEntries(for: "other").isEmpty)
        #expect(state.routeEntry(id: valid.id, districtId: "district")?.route == valid)
        #expect(state.routeEntry(id: "orphan", districtId: "district") == nil)
        #expect(state.routeEntry(id: nil, districtId: "district") == nil)
        #expect(state.routeEntry(id: valid.id, districtId: "other") == nil)
    }

    @Test("PointEntryは選択ルートのPointだけを抽出し、異なるルートを拒否する")
    func pointEntriesMatchRoute() {
        let route = AppStateFixture.route()
        let point = Point(
            id: "point", routeId: route.id,
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let state = AppStateFixture.state(
            routes: [route], points: [point], currentRouteId: route.id
        )

        #expect(state.pointEntries(for: route.id, districtId: "district").map(\.id) == ["point"])
        #expect(state.pointEntries(for: "other", districtId: "district").isEmpty)
        #expect(state.pointEntries(for: route.id, districtId: "other").isEmpty)
        #expect(state.pointEntries(for: [point], districtId: "district").map(\.id) == ["point"])
    }

    @Test("地区の並び順はgroup・nameで決まり、指定地区を同groupの先頭に移す")
    func prioritizesSelectedDistrictWithinGroup() {
        let a1 = AppStateFixture.district(id: "a1", name: "Alpha", group: "A")
        let a2 = AppStateFixture.district(id: "a2", name: "Beta", group: "A")
        let b1 = AppStateFixture.district(id: "b1", name: "Gamma", group: "B")
        let state = AppStateFixture.state(
            districts: [b1, a2, a1], selectedDistrictId: nil
        )

        #expect(state.routeDistrictIds(prioritizing: nil) == ["a1", "a2", "b1"])
        #expect(state.routeDistrictIds(prioritizing: "missing") == ["a1", "a2", "b1"])
        #expect(state.routeDistrictIds(prioritizing: "a2") == ["a2", "a1", "b1"])
        #expect(state.districtsById["a1"] == a1)
    }

    @Test("重複地区の辞書化では最初のレコードを採用する")
    func districtDictionaryRetainsFirstDuplicate() {
        let first = AppStateFixture.district(id: "same", name: "First")
        let second = AppStateFixture.district(id: "same", name: "Second")
        let state = AppStateFixture.state(
            districts: [first, second], selectedDistrictId: nil
        )

        #expect(state.districtsById["same"]?.name == "First")
    }

    @Test("既存の地区とルートは置換し、存在しないものは追加する")
    func upsertsDistrictAndRouteWithoutDuplicates() {
        var festivalState = AppStateFixture.state().festivalState
        let editedDistrict = AppStateFixture.district(name: "Edited")
        festivalState.replaceDistrict(editedDistrict)
        #expect(festivalState.districts.map(\.name) == ["Edited"])
        festivalState.replaceDistrict(AppStateFixture.district(id: "missing"))
        #expect(festivalState.districts.count == 1)
        festivalState.upsertDistrict(AppStateFixture.district(name: "Again"))
        #expect(festivalState.districts.count == 1)
        #expect(festivalState.districts.first?.name == "Again")
        festivalState.upsertDistrict(AppStateFixture.district(id: "new"))
        #expect(festivalState.districts.count == 2)
        #expect(festivalState.containsDistrict(id: "new"))
        #expect(!festivalState.containsDistrict(id: "unknown"))

        let pack = LaunchDistrictPack(
            performances: [], routes: [AppStateFixture.route()],
            points: [], passages: [], currentRouteId: nil
        )
        var districtState = DistrictState(districtId: "district", pack: pack)
        let changedRoute = AppStateFixture.route(description: "new")
        districtState.upsertRoute(changedRoute)
        #expect(districtState.routes.count == 1)
        #expect(districtState.route(id: "route")?.description == "new")
        districtState.upsertRoute(AppStateFixture.route(id: "additional"))
        #expect(districtState.routes.count == 2)
        districtState.removeRoute(id: "additional")
        #expect(districtState.routes.map(\.id) == ["route"])
        districtState.removeRoutes(outside: [])
        #expect(districtState.routes.isEmpty)
    }

    @Test("期間のUpsertと削除はIDを基準に行い、日時順を保持する")
    func updatesAndRemovesPeriods() {
        var festivalState = AppStateFixture.state().festivalState
        let later = AppStateFixture.period(id: "later", day: 6)
        festivalState.upsertPeriod(later)
        #expect(festivalState.periods.map(\.id) == ["period", "later"])
        var replacement = AppStateFixture.period()
        replacement.title = "server"
        festivalState.upsertPeriod(replacement)
        #expect(festivalState.periods.count == 2)
        #expect(festivalState.periods.first?.title == "server")
        festivalState.removePeriod(id: "period")
        #expect(festivalState.periods.map(\.id) == ["later"])
    }

    @Test("位置情報更新では地区ごとに最新レコードを優先し、不明地区を除去する")
    func latestLocationReplacementAndDeletion() {
        let old = FloatLocation(
            id: "old", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let recent = FloatLocation(
            id: "recent", districtId: "district",
            coordinate: Coordinate(latitude: 36, longitude: 140),
            timestamp: Date(timeIntervalSince1970: 200)
        )
        let unknown = FloatLocation(
            id: "unknown", districtId: "other",
            coordinate: Coordinate(latitude: 37, longitude: 141),
            timestamp: Date(timeIntervalSince1970: 300)
        )
        var state = AppStateFixture.state(locations: [old])
        #expect(state.floatEntry(for: "district")?.floatLocation.id == "old")
        #expect(state.floatEntries.map(\.id) == ["old"])

        state.festivalState.upsertFloatLocation(recent)
        #expect(state.floatLocation(for: "district")?.id == "recent")
        state.festivalState.upsertFloatLocation(unknown)
        #expect(state.floatEntries.map(\.id) == ["recent"])
        state.festivalState.replaceFloatLocations(with: [recent, old, unknown])
        #expect(state.festivalState.floatLocations.map(\.id) == ["recent"])
        state.festivalState.removeFloatLocation(for: "district")
        #expect(state.floatEntries.isEmpty)
    }
}
