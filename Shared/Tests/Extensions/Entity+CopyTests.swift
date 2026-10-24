import Foundation
import Testing
@testable import Shared

struct EntityCopyTests {
    @Test
    func point複製時に境界属性を保持する() {
        let sourceRouteId = "source-route"
        let copiedRouteId = "copied-route"
        let source = Point(
            id: "source-point",
            routeId: sourceRouteId,
            coordinate: Coordinate(latitude: 35.0, longitude: 139.0),
            index: 3,
            isBoundary: true
        )

        let copied = [source].copyWith(routeId: copiedRouteId)[0]

        #expect(copied.id != source.id)
        #expect(copied.routeId == copiedRouteId)
        #expect(copied.coordinate == source.coordinate)
        #expect(copied.index == source.index)
        #expect(copied.isBoundary)
    }
}
