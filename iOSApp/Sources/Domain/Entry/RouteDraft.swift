//
//  RouteDraft.swift
//  MaTool
//
//  Created by OpenAI Codex on 2026/06/19.
//

import Shared

struct RouteDraft: Equatable, Sendable, Identifiable {
    var route: Route
    var points: [Point]
    var passages: [RoutePassage]

    var id: Route.ID {
        route.id
    }
}
