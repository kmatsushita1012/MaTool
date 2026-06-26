//
//  DistrictAreaOverlay.swift
//  MaTool
//
//  Created by OpenAI Codex on 2026/06/25.
//

import Foundation
import Shared

struct DistrictAreaOverlay: Equatable, Hashable, Identifiable {
    let districtId: District.ID
    let districtName: String
    let area: [Coordinate]
    let center: Coordinate
    let colorIndex: Int

    var id: District.ID { districtId }
}

private let districtAreaPaletteSize = 4
private let districtAreaNearDistanceDegrees = 0.00015
private let districtAreaGeometryEpsilon = 1e-9

func assignDistrictAreaOverlays(
    districts: [District],
    nearDistanceDegrees: Double = districtAreaNearDistanceDegrees
) -> [DistrictAreaOverlay] {
    let polygons = districts
        .filter { $0.area.count >= 3 }
        .sorted()
        .map {
            DistrictAreaPolygonSource(
                districtId: $0.id,
                districtName: $0.name,
                area: $0.area,
                center: $0.area.polygonCenter,
                boundingBox: .from($0.area)
            )
        }

    guard !polygons.isEmpty else { return [] }

    let adjacency = buildAdjacency(polygons: polygons, nearDistanceDegrees: nearDistanceDegrees)
    let colorIndexByDistrictId = assignColorIndices(
        polygons: polygons,
        adjacency: adjacency,
        paletteSize: districtAreaPaletteSize
    )

    return polygons.map {
        DistrictAreaOverlay(
            districtId: $0.districtId,
            districtName: $0.districtName,
            area: $0.area,
            center: $0.center,
            colorIndex: colorIndexByDistrictId[$0.districtId, default: 0]
        )
    }
}

private func assignColorIndices(
    polygons: [DistrictAreaPolygonSource],
    adjacency: [District.ID: Set<District.ID>],
    paletteSize: Int
) -> [District.ID: Int] {
    let orderedPolygons = polygons.sorted {
        let lhsDegree = adjacency[$0.districtId, default: []].count
        let rhsDegree = adjacency[$1.districtId, default: []].count
        if lhsDegree != rhsDegree { return lhsDegree > rhsDegree }
        if $0.area.count != $1.area.count { return $0.area.count > $1.area.count }
        return $0.districtId < $1.districtId
    }

    var assigned: [District.ID: Int] = [:]

    for polygon in orderedPolygons {
        let neighborColors = Set(adjacency[polygon.districtId, default: []].compactMap { assigned[$0] })
        if let firstAvailable = (0..<paletteSize).first(where: { !neighborColors.contains($0) }) {
            assigned[polygon.districtId] = firstAvailable
            continue
        }

        let fallback = (0..<paletteSize).min { lhs, rhs in
            let lhsCount = adjacency[polygon.districtId, default: []].filter { assigned[$0] == lhs }.count
            let rhsCount = adjacency[polygon.districtId, default: []].filter { assigned[$0] == rhs }.count
            return lhsCount < rhsCount
        } ?? 0
        assigned[polygon.districtId] = fallback
    }

    return assigned
}

private func buildAdjacency(
    polygons: [DistrictAreaPolygonSource],
    nearDistanceDegrees: Double
) -> [District.ID: Set<District.ID>] {
    var adjacency = Dictionary(uniqueKeysWithValues: polygons.map { ($0.districtId, Set<District.ID>()) })

    for (index, lhs) in polygons.enumerated() {
        let expandedLhs = lhs.boundingBox.expand(nearDistanceDegrees)
        for rhs in polygons.dropFirst(index + 1) {
            if !expandedLhs.intersects(rhs.boundingBox.expand(nearDistanceDegrees)) {
                continue
            }
            if polygonDistance(lhs.area, rhs.area) <= nearDistanceDegrees {
                adjacency[lhs.districtId, default: []].insert(rhs.districtId)
                adjacency[rhs.districtId, default: []].insert(lhs.districtId)
            }
        }
    }

    return adjacency
}

private func polygonDistance(_ lhs: [Coordinate], _ rhs: [Coordinate]) -> Double {
    let lhsEdges = polygonEdges(lhs)
    let rhsEdges = polygonEdges(rhs)
    var minDistance = Double.infinity

    for lhsEdge in lhsEdges {
        for rhsEdge in rhsEdges {
            if segmentsIntersect(lhsEdge, rhsEdge) {
                return 0
            }
            minDistance = min(
                minDistance,
                min(
                    pointToSegmentDistance(lhsEdge.start, rhsEdge),
                    pointToSegmentDistance(lhsEdge.end, rhsEdge),
                    pointToSegmentDistance(rhsEdge.start, lhsEdge),
                    pointToSegmentDistance(rhsEdge.end, lhsEdge)
                )
            )
        }
    }

    return minDistance
}

private func polygonEdges(_ polygon: [Coordinate]) -> [Segment] {
    guard polygon.count >= 2 else { return [] }
    return polygon.indices.map { index in
        let next = (index + 1) % polygon.count
        return Segment(start: polygon[index], end: polygon[next])
    }
}

private func pointToSegmentDistance(_ point: Coordinate, _ segment: Segment) -> Double {
    let dx = segment.end.longitude - segment.start.longitude
    let dy = segment.end.latitude - segment.start.latitude

    if abs(dx) <= districtAreaGeometryEpsilon, abs(dy) <= districtAreaGeometryEpsilon {
        return coordinateDistance(point, segment.start)
    }

    let t = (((point.longitude - segment.start.longitude) * dx) + ((point.latitude - segment.start.latitude) * dy))
        / ((dx * dx) + (dy * dy))
    let clamped = min(max(t, 0), 1)
    let projected = Coordinate(
        latitude: segment.start.latitude + dy * clamped,
        longitude: segment.start.longitude + dx * clamped
    )
    return coordinateDistance(point, projected)
}

private func coordinateDistance(_ lhs: Coordinate, _ rhs: Coordinate) -> Double {
    hypot(lhs.latitude - rhs.latitude, lhs.longitude - rhs.longitude)
}

private func segmentsIntersect(_ lhs: Segment, _ rhs: Segment) -> Bool {
    let o1 = orientation(lhs.start, lhs.end, rhs.start)
    let o2 = orientation(lhs.start, lhs.end, rhs.end)
    let o3 = orientation(rhs.start, rhs.end, lhs.start)
    let o4 = orientation(rhs.start, rhs.end, lhs.end)

    if o1 * o2 < 0, o3 * o4 < 0 { return true }
    if abs(o1) <= districtAreaGeometryEpsilon, pointOnSegment(rhs.start, lhs) { return true }
    if abs(o2) <= districtAreaGeometryEpsilon, pointOnSegment(rhs.end, lhs) { return true }
    if abs(o3) <= districtAreaGeometryEpsilon, pointOnSegment(lhs.start, rhs) { return true }
    if abs(o4) <= districtAreaGeometryEpsilon, pointOnSegment(lhs.end, rhs) { return true }
    return false
}

private func orientation(_ a: Coordinate, _ b: Coordinate, _ c: Coordinate) -> Double {
    ((b.longitude - a.longitude) * (c.latitude - a.latitude))
        - ((b.latitude - a.latitude) * (c.longitude - a.longitude))
}

private func pointOnSegment(_ point: Coordinate, _ segment: Segment) -> Bool {
    let minLat = min(segment.start.latitude, segment.end.latitude) - districtAreaGeometryEpsilon
    let maxLat = max(segment.start.latitude, segment.end.latitude) + districtAreaGeometryEpsilon
    let minLng = min(segment.start.longitude, segment.end.longitude) - districtAreaGeometryEpsilon
    let maxLng = max(segment.start.longitude, segment.end.longitude) + districtAreaGeometryEpsilon

    return abs(orientation(segment.start, segment.end, point)) <= districtAreaGeometryEpsilon
        && (minLat...maxLat).contains(point.latitude)
        && (minLng...maxLng).contains(point.longitude)
}

private struct DistrictAreaPolygonSource {
    let districtId: District.ID
    let districtName: String
    let area: [Coordinate]
    let center: Coordinate
    let boundingBox: BoundingBox
}

private struct Segment {
    let start: Coordinate
    let end: Coordinate
}

private struct BoundingBox {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    func expand(_ delta: Double) -> Self {
        .init(
            minLatitude: minLatitude - delta,
            maxLatitude: maxLatitude + delta,
            minLongitude: minLongitude - delta,
            maxLongitude: maxLongitude + delta
        )
    }

    func intersects(_ other: Self) -> Bool {
        !(maxLatitude < other.minLatitude
            || other.maxLatitude < minLatitude
            || maxLongitude < other.minLongitude
            || other.maxLongitude < minLongitude)
    }

    static func from(_ points: [Coordinate]) -> Self {
        .init(
            minLatitude: points.map(\.latitude).min() ?? 0,
            maxLatitude: points.map(\.latitude).max() ?? 0,
            minLongitude: points.map(\.longitude).min() ?? 0,
            maxLongitude: points.map(\.longitude).max() ?? 0
        )
    }
}

private extension Array where Element == Coordinate {
    var polygonCenter: Coordinate {
        guard !isEmpty else {
            return Coordinate(latitude: 0, longitude: 0)
        }
        guard count >= 3 else {
            return Coordinate(
                latitude: map(\.latitude).reduce(0, +) / Double(count),
                longitude: map(\.longitude).reduce(0, +) / Double(count)
            )
        }

        var twiceArea = 0.0
        var centroidLatitude = 0.0
        var centroidLongitude = 0.0

        for index in indices {
            let next = (index + 1) % count
            let current = self[index]
            let following = self[next]
            let cross = (current.longitude * following.latitude) - (following.longitude * current.latitude)
            twiceArea += cross
            centroidLatitude += (current.latitude + following.latitude) * cross
            centroidLongitude += (current.longitude + following.longitude) * cross
        }

        if Swift.abs(twiceArea) <= districtAreaGeometryEpsilon {
            return Coordinate(
                latitude: map(\.latitude).reduce(0, +) / Double(count),
                longitude: map(\.longitude).reduce(0, +) / Double(count)
            )
        }

        let factor = 1 / (3 * twiceArea)
        return Coordinate(
            latitude: centroidLatitude * factor,
            longitude: centroidLongitude * factor
        )
    }
}
