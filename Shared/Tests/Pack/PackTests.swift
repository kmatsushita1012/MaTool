import Foundation
import Shared
import Testing

struct PackTests {
    @Test("LaunchFestivalPack encodes edition without the legacy year")
    func launchFestivalPackEncodesOptionalEditionAsNull() throws {
        let pack = LaunchFestivalPack(
            festival: makeFestival(),
            edition: nil,
            districts: [],
            periods: [],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )

        let data = try JSONEncoder().encode(pack)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["edition"] is NSNull)
        #expect(object["year"] == nil)
        #expect(try JSONDecoder().decode(LaunchFestivalPack.self, from: data) == pack)
    }

    @Test("LaunchDistrictPack encodes a missing editionId as null")
    func launchDistrictPackEncodesOptionalEditionIdAsNull() throws {
        let pack = LaunchDistrictPack(
            performances: [],
            routes: [],
            points: [],
            passages: [],
            currentRouteId: nil
        )

        let data = try JSONEncoder().encode(pack)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["editionId"] is NSNull)
        #expect(try JSONDecoder().decode(LaunchDistrictPack.self, from: data) == pack)
    }

    private func makeFestival() -> Festival {
        Festival(
            id: "festival-1",
            name: "Festival",
            subname: "",
            base: Coordinate(latitude: 35, longitude: 139)
        )
    }
}
