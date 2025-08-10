//
//  Fragments.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import MapKit

class PointAnnotation: MKPointAnnotation {
    enum TitleType {
        case simple
        case time(Int)
    }
    let point: Point
    init(_ point: Point,type: TitleType) {
        self.point = point
        super.init()
        switch type {
        case .simple:
            self.title = point.title
        case .time(let index):
            let hasSuffix = (point.title?.isEmpty == false) || (point.time != nil)
            let titleText = [point.title, point.time?.text]
                .compactMap { $0 }
                .joined(separator: " ")

            self.title = hasSuffix ? "\(index+1): \(titleText)" : "\(index+1)"
        }
        
    }
}

class SegmentPolyline: MKPolyline {
    var segment: Segment? = nil
}

class LocationAnnotation: MKPointAnnotation {
    let location: PublicLocation
    
    init(location: PublicLocation) {
        self.location = location
        super.init()
        self.title = location.districtId
    }
}
