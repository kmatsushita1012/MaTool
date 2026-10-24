import Foundation
import Testing
@testable import Shared

struct RouteTests {
    @Test("関連付けのないPointを時刻付きで生成した場合は時刻をnilにする")
    func 関連付けのないPoint生成時に時刻をnilにする() {
        let point = point("unused-time", index: 0, time: .init(hour: 11, minute: 30))

        #expect(point.time == nil)
    }

    @Test("Pointのnilの時刻と関連付けをJSONでnullとしてエンコードする")
    func nilの時刻と関連付けをnullとしてエンコードする() throws {
        let point = point("point", index: 0)
        let data = try JSONEncoder().encode(point)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["time"] is NSNull)
        #expect(object["checkpointId"] is NSNull)
        #expect(object["performanceId"] is NSNull)
        #expect(object["anchor"] is NSNull)
    }

    private func point(
        _ id: String,
        index: Int,
        time: SimpleTime? = nil,
        checkpointId: Checkpoint.ID? = nil,
        performanceId: Performance.ID? = nil,
        anchor: Anchor? = nil
    ) -> Point {
        Point(
            id: id,
            routeId: "route",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            time: time,
            checkpointId: checkpointId,
            performanceId: performanceId,
            anchor: anchor,
            index: index
        )
    }
}
