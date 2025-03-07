//
//  Extension.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Combine
import ComposableArchitecture
import MapKit

struct Stack<Element: Equatable>: Equatable{
    private var elements: [Element] = []
    
    mutating func push(_ element: Element) {
        elements.append(element)
    }
    
    mutating func pop() -> Element? {
        return elements.popLast()
    }
    
    func peek() -> Element? {
        return elements.last
    }
    
    var isEmpty: Bool {
        return elements.isEmpty
    }
    
    var count: Int {
        return elements.count
    }
    
    mutating func clear() -> Void{
        elements = []
    }
    
    static func == (lhs: Stack<Element>, rhs: Stack<Element>) -> Bool {
        return lhs.elements == rhs.elements
    }
}


class PointAnnotation: MKPointAnnotation{
    var id: UUID?
    static func factory(id: UUID, coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil) -> PointAnnotation{
        let annotation = PointAnnotation()
        annotation.id = id
        annotation.coordinate = coordinate
        annotation.title = title
        annotation.subtitle = subtitle
        return annotation
    }
}

class SegmentPolyline:MKPolyline {
    var id: UUID?
    static func factory(id: UUID, coordinates: [CLLocationCoordinate2D]) -> SegmentPolyline{
        let polyline = SegmentPolyline(coordinates: coordinates, count: coordinates.count)
        polyline.id = id
        return polyline
    }
}
