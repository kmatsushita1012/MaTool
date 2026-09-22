//
//  RouteDraft.swift
//  MaTool
//
//  Created by OpenAI Codex on 2026/06/19.
//

import Shared

public struct RouteDraft: Equatable, Sendable, Identifiable {
    public var route: Route
    public var points: [Point]
    public var passages: [RoutePassage]

    public var id: Route.ID {
        route.id
    }

    public init(route: Route, points: [Point], passages: [RoutePassage]) {
        self.route = route
        self.points = points
        self.passages = passages
    }
}
