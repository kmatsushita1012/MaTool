import Foundation
import Shared
import Testing
@testable import iOSApp

struct AppStateTests {
    @Test("重複位置情報は地区ごとに最新を採用し、未知の地区を除外する")
    func festivalStateKeepsLatestKnownLocation() {
        let district = AppStateFixture.district()
        let older = FloatLocation(
            id: "older", districtId: district.id,
            coordinate: Coordinate(latitude: 35, longitude: 139),
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let newer = FloatLocation(
            id: "newer", districtId: district.id,
            coordinate: Coordinate(latitude: 36, longitude: 140),
            timestamp: Date(timeIntervalSince1970: 200)
        )
        let unknown = FloatLocation(
            id: "unknown", districtId: "unknown",
            coordinate: Coordinate(latitude: 37, longitude: 141),
            timestamp: Date(timeIntervalSince1970: 300)
        )

        let state = AppStateFixture.state(
            districts: [district], locations: [newer, older, unknown]
        )

        #expect(state.festivalState.floatLocations.map(\.id) == ["newer"])
        #expect(state.festivalState.year == 2026)
    }

    @Test("同一タイムスタンプでは先に受信した位置情報を維持する")
    func equalTimestampKeepsFirstLocation() {
        let date = Date(timeIntervalSince1970: 100)
        let first = FloatLocation(
            id: "first", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139), timestamp: date
        )
        let second = FloatLocation(
            id: "second", districtId: "district",
            coordinate: Coordinate(latitude: 36, longitude: 140), timestamp: date
        )

        let state = AppStateFixture.state(locations: [first, second])

        #expect(state.festivalState.floatLocations.map(\.id) == ["first"])
    }

    @Test("選択ルートのPointとPassageはルートIDに一致するものだけ保持する")
    func routeStateFiltersForeignChildren() {
        let route = AppStateFixture.route()
        let expected = Point(
            id: "expected", routeId: route.id,
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let unrelated = Point(
            id: "unrelated", routeId: "other",
            coordinate: Coordinate(latitude: 36, longitude: 140)
        )
        let passage = RoutePassage(id: "matched", routeId: route.id, order: 1)
        let foreignPassage = RoutePassage(id: "foreign", routeId: "other", order: 2)

        let state = AppStateFixture.state(
            routes: [route], points: [expected, unrelated],
            passages: [passage, foreignPassage], currentRouteId: route.id
        )

        #expect(state.routeState?.route == route)
        #expect(state.routeState?.points.map(\.id) == ["expected"])
        #expect(state.routeState?.passages.map(\.id) == ["matched"])
    }

    @Test("選択ルートが存在しない場合はRouteStateを生成しない")
    func missingCurrentRouteDoesNotCreateRouteState() {
        let state = AppStateFixture.state(
            routes: [AppStateFixture.route()], currentRouteId: "unknown"
        )
        #expect(state.routeState == nil)
    }

    @Test("DistrictPackがない場合はDistrictStateとRouteStateを生成しない")
    func noDistrictSelectionHasNoDistrictState() {
        let state = AppStateFixture.state(selectedDistrictId: nil)

        #expect(state.districtState == nil)
        #expect(state.routeState == nil)
        #expect(state.festivalState.festival.id == "festival")
    }
}
