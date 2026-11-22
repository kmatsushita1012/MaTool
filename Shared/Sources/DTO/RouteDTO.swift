public struct RouteEntry: DTO, Identifiable, Comparable {
    public let period: Period
    public let route: Route

    public init(period: Period, route: Route) {
        self.period = period
        self.route = route
    }

    public var id: Route.ID { route.id }

    public static func < (lhs: RouteEntry, rhs: RouteEntry) -> Bool {
        lhs.period < rhs.period
    }
}

public struct EditionRouteGroup: DTO {
    public let edition: Edition
    public let entries: [RouteEntry]

    public init(edition: Edition, entries: [RouteEntry]) {
        self.edition = edition
        self.entries = entries
    }
}

public struct RouteHistoryResponse: DTO {
    public let editions: [EditionRouteGroup]

    public init(editions: [EditionRouteGroup]) {
        self.editions = editions
    }
}
