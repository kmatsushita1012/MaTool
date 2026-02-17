//
//  Entity+Mock.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/02/16.
//

import Shared
import Foundation

// MARK: - Primitive/Nested value types
extension Coordinate {
    static var mock: Self { .init(latitude: 0, longitude: 0) }
}

// If ImagePath exists in Shared, provide a default mock.
// Using empty initializer as per Festival default.
extension ImagePath {
    static var mock: Self { .init() }
}

extension SimpleDate {
    static var mock: Self { .init(year: 2026, month: 1, day: 1) }
}

// If SimpleTime exists and is used by Point, provide a simple mock.
extension SimpleTime {
    static var mock: Self { .init(hour: 0, minute: 0) }
}

// MARK: - Enums
extension Visibility {
    static var mock: Self { .all }
}

extension Anchor {
    static var mock: Self { .start }
}

// MARK: - Festival
extension Festival {
    static func mock(id: Self.ID = "f-id") -> Self {
        .init(
            id: id,
            name: "",
            subname: "",
            description: nil,
            prefecture: "",
            city: "",
            base: .mock,
            image: .mock
        )
    }
}
extension Checkpoint {
    static func mock(id: Self.ID = "cp-id", festivalId: Festival.ID = "f-id") -> Self {
        .init(id: id, name: "", festivalId: festivalId, description: nil)
    }
}

extension HazardSection {
    static func mock(
        id: Self.ID = "hz-id",
        festivalId: Festival.ID = "f-id"
    ) -> Self {
        .init(id: id, title: "", festivalId: festivalId, coordinates: [.mock])
    }
}

// MARK: - District系
extension District {
    static func mock(
        id: Self.ID = "d-id",
        festivalId: Festival.ID = "f-id",
        name: String = ""
    ) -> Self {
        .init(id: id, name: name, festivalId: festivalId)
    }
}

extension Performance {
    static func mock(
        id: Self.ID = "pf-id",
        districtId: Festival.ID = "f-id"
    ) -> Self {
        .init(id: id, districtId: districtId)
    }
}

// MARK: - Period
extension Period {
    static func mock(
        id: Self.ID = "p-id",
        festivalId: Festival.ID = "f-id",
        date: SimpleDate = .mock
    ) -> Self {
        .init(id: id, festivalId: festivalId, date: date)
    }
}

// MARK: - Route
extension Route {
    static func mock(
        id: Self.ID = "r-id",
        districtId: District.ID = "d-id",
        periodId: Period.ID = "p-id"
    ) -> Self {
        .init(
            id: id,
            districtId: districtId,
            periodId: periodId,
            visibility: .mock,
            description: nil
        )
    }
}

extension Point {
    static func mock(
        id: Self.ID = "pt-id",
        routeId: Route.ID = "r-id"
    ) -> Self {
        .init(
            id: id,
            routeId: routeId,
            coordinate: .mock,
            time: nil,
            checkpointId: nil,
            performanceId: nil,
            anchor: .mock,
            index: 0,
            isBoundary: false
        )
    }
}

// MARK: - FloatLocation
extension FloatLocation {
    static func mock(
        id: Self.ID = "fl-id",
        districtId: District.ID = "d-id",
        coordinate: Coordinate = .mock,
        timestamp: Date = Date(timeIntervalSince1970: 0)
    ) -> Self {
        .init(id: id, districtId: districtId, coordinate: coordinate, timestamp: timestamp)
    }
}

// MARK: - Packs
extension RouteDetailPack {
    static func mock(
        route: Route = .mock(),
        points: [Point] = [Point.mock()]
    ) -> Self {
        .init(route: route, points: points)
    }
}

extension FestivalPack {
    static func mock(
        festival: Festival = .mock(),
        checkpoints: [Checkpoint] = [Checkpoint.mock()],
        hazardSections: [HazardSection] = [HazardSection.mock()]
    ) -> Self {
        .init(festival: festival, checkpoints: checkpoints, hazardSections: hazardSections)
    }
}

extension DistrictPack {
    static func mock(
        district: District = .mock(),
        performances: [Performance] = [Performance.mock()]
    ) -> Self {
        .init(district: district, performances: performances)
    }
}
