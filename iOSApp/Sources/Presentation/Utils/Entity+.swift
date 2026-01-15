//
//  Entity+.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/26.
//

import MapKit
import Shared

extension Point{
    func annotation(type: PointAnnotation.TitleType = .simple) -> PointAnnotation {
        PointAnnotation(self, type: type)
    }
}

extension Array where Element == Point {
    var pair: [Pair<Point>] {
        guard count > 1 else { return [] }
        return zip(self, dropFirst()).map { Pair(first: $0, second: $1) }
    }
}

extension Pair where Element == Point {
    var polyline: PathPolyline {
        let coords = [self.first, self.second].map { $0.coordinate.toCL() }
        let polyline = PathPolyline(coordinates: coords, count: coords.count)
        return polyline
    }
}

extension Period {
    var text: String {
        String(
            format: "%d/%d %@ %02d:%02d〜%02d:%02d",
            date.month,
            date.day,
            title,
            start.hour,
            start.minute,
            end.hour,
            end.minute
        )
    }
}
