import Testing
@testable import Shared

struct RouteBoundarySegmenterTest {
    @Test
    func splitCoordinatesByBoundary_境界で分割する() {
        let routeID = "route-1"
        let points: [Point] = [
            .init(routeId: routeID, coordinate: .init(latitude: 35.0, longitude: 139.0), index: 0, isBoundary: false),
            .init(routeId: routeID, coordinate: .init(latitude: 35.1, longitude: 139.1), index: 1, isBoundary: true),
            .init(routeId: routeID, coordinate: .init(latitude: 35.2, longitude: 139.2), index: 2, isBoundary: false),
            .init(routeId: routeID, coordinate: .init(latitude: 35.3, longitude: 139.3), index: 3, isBoundary: false)
        ]

        let segments = RouteBoundarySegmenter.splitCoordinatesByBoundary(points: points)

        #expect(segments.count == 2)
        #expect(segments[0].count == 2)
        #expect(segments[1].count == 3)
        #expect(segments[0][0] == points[0].coordinate)
        #expect(segments[1][0] == points[1].coordinate)
    }

    @Test
    func splitCoordinatesByBoundary_単点セグメントは除外する() {
        let routeID = "route-1"
        let points: [Point] = [
            .init(routeId: routeID, coordinate: .init(latitude: 35.0, longitude: 139.0), index: 0, isBoundary: true)
        ]

        let segments = RouteBoundarySegmenter.splitCoordinatesByBoundary(points: points)

        #expect(segments.isEmpty)
    }
}
