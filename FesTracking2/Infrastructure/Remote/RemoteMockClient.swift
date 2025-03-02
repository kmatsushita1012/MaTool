//
//  MockRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Combine
import Dependencies
extension RemoteClient: TestDependencyKey {
    static let testValue = normal
    static let previewValue = normal

    static let normal = Self(
        getRegions:{
            return [Region(id: UUID(), name: "掛川祭", description: "省略", imagePath: nil)]
        },
        getDistricts: {_ in
            return [District(id: UUID(), name: "城北町", description: "省略", imagePath: nil)]
        },
        getRouteList: {_ in
            return [RouteSummary(id: UUID(), date: Date(year: 2025, month: 10, day: 12), title: "午前")]
            
        },
        getRouteDetail: {_ in
            return
                Route(
                    id: UUID(),
                    points: [
                        Point(coordinate: Coordinate(latitude: 34.777681, longitude: 138.007029), title: "出発", time: Time(hour: 9, minute: 0)),
                        Point(coordinate: Coordinate(latitude: 34.778314, longitude: 138.008176), title: "到着", description: "お疲れ様です", time: Time(hour: 12, minute: 0))
                    ],
                    segments: [
                        Segment(
                            points:[
                                Coordinate(latitude: 34.777681, longitude: 138.007029),
                                Coordinate(latitude: 34.777730, longitude: 138.008174),
                                Coordinate(latitude: 34.778314, longitude: 138.008176),
                            ]
                        )
                    ],
                    current: Point(coordinate: Coordinate(latitude: 34.777681, longitude: 138.007029), title: "屋台", time: Time(hour: 9, minute: 1)),
                    date: Date(year: 2025, month: 10, day: 12),
                    title: "午後",
                    description: "省略"
                
            )
            
        })
}


