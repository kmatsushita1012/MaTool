public enum RouteBoundarySegmenter {
    public static func splitCoordinatesByBoundary(points: [Point]) -> [[Coordinate]] {
        let coordinates = points.map(\.coordinate)
        guard points.count == coordinates.count else { return [coordinates] }

        var result: [[Coordinate]] = []
        var current: [Coordinate] = []

        for (index, coordinate) in coordinates.enumerated() {
            current.append(coordinate)

            let isBoundary = points[index].isBoundary
            if isBoundary && !current.isEmpty {
                result.append(current)
                current = [coordinate]
            }
        }

        if !current.isEmpty {
            result.append(current)
        }
        return result.filter { $0.count >= 2 }
    }
}
