import Foundation

public struct RoutePassageAutoDetector {
    public enum BoundaryMode: Sendable {
        case includeTouch
        case excludeTouch
    }

    private struct BoundingBox: Sendable {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double

        func intersects(_ other: Self) -> Bool {
            !(maxLat < other.minLat || other.maxLat < minLat || maxLon < other.minLon || other.maxLon < minLon)
        }
    }

    private struct DistrictPolygon: Sendable {
        let districtId: District.ID
        let area: [Coordinate]
        let boundingBox: BoundingBox
    }

    private struct PassageEvent: Sendable {
        let districtId: District.ID
        let parameter: Double
        let districtOrder: Int
    }

    private let mode: BoundaryMode
    private let epsilon: Double

    public init(mode: BoundaryMode = .includeTouch, epsilon: Double = 1e-9) {
        self.mode = mode
        self.epsilon = epsilon
    }

    // Main entry:
    // 1) route を隣接点の線分に分解
    // 2) 各線分で「どの district に入ったか」を検出
    // 3) 線分上の進行順で event を並べる
    // 4) 連続重複（境界付近の誤判定ノイズ）を圧縮して RoutePassage を返す
    public func makePassages(routeId: Route.ID, points: [Point], districts: [District]) -> [RoutePassage] {
        guard points.count >= 2 else { return [] }

        let polygons = districts.compactMap(makeDistrictPolygon)
        guard !polygons.isEmpty else { return [] }

        var activeDistricts = Set<District.ID>()
        var passedDistrictIds: [District.ID] = []

        for segmentIndex in 0..<(points.count - 1) {
            let start = points[segmentIndex].coordinate
            let end = points[segmentIndex + 1].coordinate
            if isSameCoordinate(start, end) {
                continue
            }

            let segmentBox = makeBoundingBox(start, end)
            let midpoint = Coordinate(
                latitude: (start.latitude + end.latitude) / 2.0,
                longitude: (start.longitude + end.longitude) / 2.0
            )
            // 同一線分で複数 district に入る可能性があるため、
            // いったん event として集めて t(線分上の位置) でソートする。
            var events: [PassageEvent] = []

            for (districtOrder, polygon) in polygons.enumerated() {
                guard segmentBox.intersects(polygon.boundingBox) else { continue }

                let startInside = pointInPolygon(start, polygon.area)
                let endInside = pointInPolygon(end, polygon.area)
                let firstIntersection = firstIntersectionParameter(start, end, polygon.area)
                let midpointInside = pointInPolygon(midpoint, polygon.area)
                let enters = startInside || endInside || firstIntersection != nil || midpointInside

                // active でない district へ入ったと判断したときのみ event 追加。
                // event の parameter は「線分のどこで入ったか」の近似値。
                if !activeDistricts.contains(polygon.districtId), enters {
                    let parameter = if startInside {
                        0.0
                    } else if let firstIntersection {
                        firstIntersection
                    } else if midpointInside {
                        0.5
                    } else {
                        1.0
                    }
                    events.append(
                        PassageEvent(
                            districtId: polygon.districtId,
                            parameter: parameter,
                            districtOrder: districtOrder
                        )
                    )
                }

                // 次線分に向けた在圏状態を end 点で更新。
                // これにより「退出→再突入」を別イベントとして扱える。
                if endInside {
                    activeDistricts.insert(polygon.districtId)
                } else {
                    activeDistricts.remove(polygon.districtId)
                }
            }

            // ルート進行順を優先。t が同値なら districts の元順で安定化。
            events.sort {
                if abs($0.parameter - $1.parameter) <= epsilon {
                    return $0.districtOrder < $1.districtOrder
                }
                return $0.parameter < $1.parameter
            }
            passedDistrictIds.append(contentsOf: events.map(\.districtId))
        }

        let normalizedDistrictIds = collapseConsecutiveDuplicates(passedDistrictIds)

        return normalizedDistrictIds.enumerated().map { order, districtId in
            RoutePassage(routeId: routeId, districtId: districtId, memo: nil, order: order)
        }
    }
}

private extension RoutePassageAutoDetector {
    private func makeDistrictPolygon(_ district: District) -> DistrictPolygon? {
        guard district.area.count >= 3 else { return nil }
        return DistrictPolygon(
            districtId: district.id,
            area: district.area,
            boundingBox: makeBoundingBox(district.area)
        )
    }

    private func makeBoundingBox(_ points: [Coordinate]) -> BoundingBox {
        var minLat = points[0].latitude
        var maxLat = points[0].latitude
        var minLon = points[0].longitude
        var maxLon = points[0].longitude
        for point in points.dropFirst() {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        return BoundingBox(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }

    private func makeBoundingBox(_ a: Coordinate, _ b: Coordinate) -> BoundingBox {
        BoundingBox(
            minLat: min(a.latitude, b.latitude),
            maxLat: max(a.latitude, b.latitude),
            minLon: min(a.longitude, b.longitude),
            maxLon: max(a.longitude, b.longitude)
        )
    }

    private func firstIntersectionParameter(_ a: Coordinate, _ b: Coordinate, _ polygon: [Coordinate]) -> Double? {
        var first: Double?
        for index in polygon.indices {
            let c = polygon[index]
            let d = polygon[(index + 1) % polygon.count]
            if let parameter = segmentIntersectionParameter(a, b, c, d) {
                if let current = first {
                    if parameter < current {
                        first = parameter
                    }
                } else {
                    first = parameter
                }
            }
        }
        return first
    }

    // 2線分 AB, CD の交点を、AB 上の parameter t(0...1) で返す。
    // includeTouch: 端点接触/共線接触も拾う
    // excludeTouch: 厳密な内部交差のみ拾う
    private func segmentIntersectionParameter(_ a: Coordinate, _ b: Coordinate, _ c: Coordinate, _ d: Coordinate) -> Double? {
        let rX = b.longitude - a.longitude
        let rY = b.latitude - a.latitude
        let sX = d.longitude - c.longitude
        let sY = d.latitude - c.latitude
        let qpX = c.longitude - a.longitude
        let qpY = c.latitude - a.latitude

        let rCrossS = cross(rX, rY, sX, sY)
        let qpCrossR = cross(qpX, qpY, rX, rY)

        if abs(rCrossS) <= epsilon, abs(qpCrossR) <= epsilon {
            if mode == .excludeTouch {
                return nil
            }
            var candidates: [Double] = []
            if pointOnSegment(c, a, b), let t = parameterOnSegment(c, a, b) { candidates.append(t) }
            if pointOnSegment(d, a, b), let t = parameterOnSegment(d, a, b) { candidates.append(t) }
            if pointOnSegment(a, c, d) { candidates.append(0.0) }
            if pointOnSegment(b, c, d) { candidates.append(1.0) }
            return candidates.min()
        }

        if abs(rCrossS) <= epsilon {
            return nil
        }

        let t = cross(qpX, qpY, sX, sY) / rCrossS
        let u = cross(qpX, qpY, rX, rY) / rCrossS

        let segmentRange = (-epsilon)...(1.0 + epsilon)
        guard segmentRange.contains(t), segmentRange.contains(u) else { return nil }

        if mode == .excludeTouch {
            let strictRange = epsilon..<(1.0 - epsilon)
            guard strictRange.contains(t), strictRange.contains(u) else { return nil }
        }
        return min(max(t, 0.0), 1.0)
    }

    private func pointInPolygon(_ point: Coordinate, _ polygon: [Coordinate]) -> Bool {
        let onBoundary = pointOnPolygonBoundary(point, polygon)
        if onBoundary {
            return mode == .includeTouch
        }

        var inside = false
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]

            let crossesLatitude = (a.latitude > point.latitude) != (b.latitude > point.latitude)
            guard crossesLatitude else { continue }

            let intersectionLon = ((b.longitude - a.longitude) * (point.latitude - a.latitude) / (b.latitude - a.latitude)) + a.longitude
            if point.longitude < intersectionLon {
                inside.toggle()
            }
        }
        return inside
    }

    private func pointOnPolygonBoundary(_ point: Coordinate, _ polygon: [Coordinate]) -> Bool {
        for index in polygon.indices {
            if pointOnSegment(point, polygon[index], polygon[(index + 1) % polygon.count]) {
                return true
            }
        }
        return false
    }

    private func pointOnSegment(_ point: Coordinate, _ a: Coordinate, _ b: Coordinate) -> Bool {
        let cross = orientation(a, b, point)
        if abs(cross) > epsilon {
            return false
        }
        let minLat = min(a.latitude, b.latitude) - epsilon
        let maxLat = max(a.latitude, b.latitude) + epsilon
        let minLon = min(a.longitude, b.longitude) - epsilon
        let maxLon = max(a.longitude, b.longitude) + epsilon
        return point.latitude >= minLat
            && point.latitude <= maxLat
            && point.longitude >= minLon
            && point.longitude <= maxLon
    }

    private func orientation(_ a: Coordinate, _ b: Coordinate, _ c: Coordinate) -> Double {
        (b.longitude - a.longitude) * (c.latitude - a.latitude)
            - (b.latitude - a.latitude) * (c.longitude - a.longitude)
    }

    private func parameterOnSegment(_ point: Coordinate, _ a: Coordinate, _ b: Coordinate) -> Double? {
        let deltaLon = b.longitude - a.longitude
        let deltaLat = b.latitude - a.latitude
        if abs(deltaLon) >= abs(deltaLat) {
            guard abs(deltaLon) > epsilon else { return nil }
            return (point.longitude - a.longitude) / deltaLon
        } else {
            guard abs(deltaLat) > epsilon else { return nil }
            return (point.latitude - a.latitude) / deltaLat
        }
    }

    private func cross(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        (x1 * y2) - (y1 * x2)
    }

    // 同じ district が連続して並ぶケースを 1 件に圧縮する。
    // 境界ぎりぎりの線分で「出入り判定が細かく揺れる」場合のノイズ除去が目的。
    private func collapseConsecutiveDuplicates(_ ids: [District.ID]) -> [District.ID] {
        guard !ids.isEmpty else { return [] }
        var result: [District.ID] = []
        result.reserveCapacity(ids.count)
        for id in ids {
            if result.last != id {
                result.append(id)
            }
        }
        return result
    }

    private func isSameCoordinate(_ lhs: Coordinate, _ rhs: Coordinate) -> Bool {
        abs(lhs.latitude - rhs.latitude) <= epsilon
            && abs(lhs.longitude - rhs.longitude) <= epsilon
    }
}
