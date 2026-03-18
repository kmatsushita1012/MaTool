import Testing
@testable import Shared

struct RoutePassageAutoDetectorTests {
    @Test
    func makePassages_通過順でRoutePassage生成() {
        let routeId = "route-1"
        let points = [
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.0), index: 0),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 10.0), index: 1)
        ]
        let districts = [
            District(
                id: "district-a",
                name: "A",
                festivalId: "festival",
                area: [
                    .init(latitude: -1, longitude: 1),
                    .init(latitude: 1, longitude: 1),
                    .init(latitude: 1, longitude: 3),
                    .init(latitude: -1, longitude: 3)
                ]
            ),
            District(
                id: "district-b",
                name: "B",
                festivalId: "festival",
                area: [
                    .init(latitude: -1, longitude: 5),
                    .init(latitude: 1, longitude: 5),
                    .init(latitude: 1, longitude: 7),
                    .init(latitude: -1, longitude: 7)
                ]
            )
        ]

        let detector = RoutePassageAutoDetector(mode: .includeTouch)
        let passages = detector.makePassages(routeId: routeId, points: points, districts: districts)

        #expect(passages.count == 2)
        #expect(passages.map(\.districtId) == ["district-a", "district-b"])
        #expect(passages.map(\.order) == [0, 1])
        #expect(passages.allSatisfy { $0.routeId == routeId && $0.memo == nil })
    }

    @Test
    func makePassages_境界接触はexcludeTouchで除外() {
        let routeId = "route-1"
        let points = [
            Point(routeId: routeId, coordinate: .init(latitude: 1.0, longitude: 0.0), index: 0),
            Point(routeId: routeId, coordinate: .init(latitude: 1.0, longitude: 2.0), index: 1)
        ]
        let districts = [
            District(
                id: "district-a",
                name: "A",
                festivalId: "festival",
                area: [
                    .init(latitude: 0, longitude: 0),
                    .init(latitude: 1, longitude: 0),
                    .init(latitude: 1, longitude: 2),
                    .init(latitude: 0, longitude: 2)
                ]
            )
        ]

        let includeTouch = RoutePassageAutoDetector(mode: .includeTouch)
            .makePassages(routeId: routeId, points: points, districts: districts)
        let excludeTouch = RoutePassageAutoDetector(mode: .excludeTouch)
            .makePassages(routeId: routeId, points: points, districts: districts)

        #expect(includeTouch.map(\.districtId) == ["district-a"])
        #expect(excludeTouch.isEmpty)
    }

    @Test
    func makePassages_不正入力は安全に空結果() {
        let routeId = "route-1"
        let points = [Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.0), index: 0)]
        let districts = [
            District(
                id: "district-invalid",
                name: "Invalid",
                festivalId: "festival",
                area: [
                    .init(latitude: 0, longitude: 0),
                    .init(latitude: 1, longitude: 1)
                ]
            )
        ]

        let detector = RoutePassageAutoDetector(mode: .includeTouch)
        let passages = detector.makePassages(routeId: routeId, points: points, districts: districts)

        #expect(passages.isEmpty)
    }

    @Test
    func makePassages_index未採番でも配列順で判定する() {
        let routeId = "route-1"
        let points = [
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.0), index: 0),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 10.0), index: 0)
        ]
        let districts = [
            District(
                id: "district-a",
                name: "A",
                festivalId: "festival",
                area: [
                    .init(latitude: -1, longitude: 1),
                    .init(latitude: 1, longitude: 1),
                    .init(latitude: 1, longitude: 3),
                    .init(latitude: -1, longitude: 3)
                ]
            )
        ]

        let detector = RoutePassageAutoDetector(mode: .includeTouch)
        let passages = detector.makePassages(routeId: routeId, points: points, districts: districts)

        #expect(passages.map(\.districtId) == ["district-a"])
    }

    @Test
    func makePassages_起点終点が内包なら通過扱い() {
        let routeId = "route-1"
        let points = [
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.0), index: 0),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.2), index: 1)
        ]
        let districts = [
            District(
                id: "district-a",
                name: "A",
                festivalId: "festival",
                area: [
                    .init(latitude: -1, longitude: -1),
                    .init(latitude: 1, longitude: -1),
                    .init(latitude: 1, longitude: 1),
                    .init(latitude: -1, longitude: 1)
                ]
            )
        ]

        let detector = RoutePassageAutoDetector(mode: .includeTouch)
        let passages = detector.makePassages(routeId: routeId, points: points, districts: districts)

        #expect(passages.map(\.districtId) == ["district-a"])
    }

    @Test
    func makePassages_同じ町が連続したら1件に圧縮される() {
        let routeId = "route-1"
        let points = [
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.0), index: 0),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 2.0), index: 1),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 4.0), index: 2),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 2.0), index: 3),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.0), index: 4)
        ]
        let districts = [
            District(
                id: "district-a",
                name: "A",
                festivalId: "festival",
                area: [
                    .init(latitude: -1, longitude: 1),
                    .init(latitude: 1, longitude: 1),
                    .init(latitude: 1, longitude: 3),
                    .init(latitude: -1, longitude: 3)
                ]
            )
        ]

        let detector = RoutePassageAutoDetector(mode: .includeTouch)
        let passages = detector.makePassages(routeId: routeId, points: points, districts: districts)

        #expect(passages.map(\.districtId) == ["district-a"])
        #expect(passages.map(\.order) == [0])
    }

    @Test
    func makePassages_別の町を挟む再突入は保持される() {
        let routeId = "route-1"
        let points = [
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.0), index: 0),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 2.0), index: 1),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 6.0), index: 2),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 2.0), index: 3)
        ]
        let districts = [
            District(
                id: "district-a",
                name: "A",
                festivalId: "festival",
                area: [
                    .init(latitude: -1, longitude: 1),
                    .init(latitude: 1, longitude: 1),
                    .init(latitude: 1, longitude: 3),
                    .init(latitude: -1, longitude: 3)
                ]
            ),
            District(
                id: "district-b",
                name: "B",
                festivalId: "festival",
                area: [
                    .init(latitude: -1, longitude: 4),
                    .init(latitude: 1, longitude: 4),
                    .init(latitude: 1, longitude: 7),
                    .init(latitude: -1, longitude: 7)
                ]
            )
        ]

        let detector = RoutePassageAutoDetector(mode: .includeTouch)
        let passages = detector.makePassages(routeId: routeId, points: points, districts: districts)

        #expect(passages.map(\.districtId) == ["district-a", "district-b", "district-a"])
    }

    @Test
    func makePassages_同一線分で複数通過してもルート進行順になる() {
        let routeId = "route-1"
        let points = [
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 0.0), index: 0),
            Point(routeId: routeId, coordinate: .init(latitude: 0.0, longitude: 10.0), index: 1)
        ]
        let district1 = District(
            id: "district-1",
            name: "1",
            festivalId: "festival",
            area: [
                .init(latitude: -1, longitude: 1),
                .init(latitude: 1, longitude: 1),
                .init(latitude: 1, longitude: 3),
                .init(latitude: -1, longitude: 3)
            ]
        )
        let district2 = District(
            id: "district-2",
            name: "2",
            festivalId: "festival",
            area: [
                .init(latitude: -1, longitude: 5),
                .init(latitude: 1, longitude: 5),
                .init(latitude: 1, longitude: 7),
                .init(latitude: -1, longitude: 7)
            ]
        )

        // districts 配列順を逆にしても、通過順は route 進行順を期待
        let detector = RoutePassageAutoDetector(mode: .includeTouch)
        let passages = detector.makePassages(routeId: routeId, points: points, districts: [district2, district1])

        #expect(passages.map(\.districtId) == ["district-1", "district-2"])
    }
}
