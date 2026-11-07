import Foundation
import Shared
import Testing
@testable import iOSApp

struct AppStateLookupsTests {
    @Test("同一地区ではtimestampが新しい位置だけを保持する")
    func keepsNewestLocationForDistrict() {
        let district = District(id: "district-1", name: "District", festivalId: "festival-1")
        let festival = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        var state = FestivalState(
            LaunchFestivalPack(
                festival: festival,
                districts: [district],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        )
        let older = FloatLocation(
            id: "old",
            districtId: district.id,
            coordinate: Coordinate(latitude: 35, longitude: 139),
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let newer = FloatLocation(
            id: "new",
            districtId: district.id,
            coordinate: Coordinate(latitude: 36, longitude: 140),
            timestamp: Date(timeIntervalSince1970: 200)
        )

        state.upsertFloatLocation(newer)
        state.upsertFloatLocation(older)

        #expect(state.floatLocations == [newer])

        state.replaceFloatLocations(with: [older])

        #expect(state.floatLocations == [newer])
    }

    @Test("一括取得内で同じ地区のtimestampが同じ場合は既存値を維持する")
    func keepsExistingLocationWhenTimestampMatches() {
        let district = District(id: "district-1", name: "District", festivalId: "festival-1")
        let festival = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        var state = FestivalState(
            LaunchFestivalPack(
                festival: festival,
                districts: [district],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        )
        let existing = FloatLocation(
            id: "existing",
            districtId: district.id,
            coordinate: Coordinate(latitude: 35, longitude: 139),
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let sameTimestamp = FloatLocation(
            id: "response",
            districtId: district.id,
            coordinate: Coordinate(latitude: 36, longitude: 140),
            timestamp: existing.timestamp
        )
        state.upsertFloatLocation(existing)

        state.replaceFloatLocations(with: [sameTimestamp])

        #expect(state.floatLocations == [existing])
    }
}
