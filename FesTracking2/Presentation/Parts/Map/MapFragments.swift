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
        case time
    }
    let point: Point
    init(_ point: Point,type: TitleType) {
        self.point = point
        super.init()
        switch type {
        case .simple:
            self.title = point.title
        case .time:
            if let title = point.title,
               let time = point.time?.text{
                self.title = title + time
            }
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
