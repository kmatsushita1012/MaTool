//
//  EditableRoute.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/12.
//

struct EditableRoute {
    var districtId: String
    var date:SimpleDate = .today
    var title: String = ""
    var description: String?
    var points: [Point] = []
    var segments: [Segment] = []
    var start: SimpleTime?
    var goal: SimpleTime?
    
}

extension EditableRoute: Equatable{}

extension EditableRoute {
    init(from route: Route) {
        self.districtId = route.districtId
        self.date = route.date
        self.title = route.title
        self.description = route.description
        self.points = route.points
        self.segments = route.segments
        self.start = route.start
        self.goal = route.goal
    }

    func toRoute() -> Route {
        return Route(
            districtId: districtId,
            date: date,
            title: title,
            points: points,
            segments: segments,
            description: description,
            start: start,
            goal: goal
        )
    }
}
