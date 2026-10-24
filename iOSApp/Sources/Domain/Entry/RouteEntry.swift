import Shared

struct RouteSlot: Entity, Identifiable {
    let period: Period
    let route: Route?

    var id: String { period.id }
    var text: String { period.shortText }
}

struct RouteEntry: Equatable, Identifiable, Comparable, Sendable {
    let period: Period
    let route: Route

    var id: String { route.id }

    var text: String {
        let dateText = period.date.text(format: "m/d")
        let weekdayText = period.date.weekdaySymbol ?? ""
        return "\(dateText)（\(weekdayText)）\(period.title)"
    }

    static func < (lhs: RouteEntry, rhs: RouteEntry) -> Bool {
        lhs.period < rhs.period
    }
}
