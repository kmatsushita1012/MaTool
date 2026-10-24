import Foundation
import Testing
@testable import Shared

struct PointValidationTests {
    @Test("関連付けのないPointに残った時刻は単調増加判定から除外する")
    func 関連付けのないPointの時刻を無視する() {
        var unusedTimePoint = point("unused-time", index: 1)
        unusedTimePoint.time = .init(hour: 11, minute: 30)
        let points = [
            point("start", index: 0, time: .init(hour: 9, minute: 0), anchor: .start),
            unusedTimePoint,
            point(
                "checkpoint",
                index: 2,
                time: .init(hour: 11, minute: 15),
                checkpointId: "checkpoint"
            ),
            point("end", index: 3, time: .init(hour: 12, minute: 0), anchor: .end)
        ]

        #expect(points[1].time == .init(hour: 11, minute: 30))
        #expect(points.normalized()[1].time == nil)
        #expect(throws: Never.self) { try points.validate() }
    }

    @Test("関連付けのあるPoint同士の時刻逆転は検出する")
    func 関連付けのあるPointの時刻逆転を検出する() {
        let points = [
            point("start", index: 0, time: .init(hour: 9, minute: 0), anchor: .start),
            point(
                "checkpoint",
                index: 1,
                time: .init(hour: 11, minute: 30),
                checkpointId: "checkpoint"
            ),
            point(
                "performance",
                index: 2,
                time: .init(hour: 11, minute: 15),
                performanceId: "performance"
            ),
            point("end", index: 3, time: .init(hour: 12, minute: 0), anchor: .end)
        ]

        #expect(throws: Point.Error.self) { try points.validate() }
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
