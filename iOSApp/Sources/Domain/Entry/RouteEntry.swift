import Shared

struct RouteSlot: Entity, Identifiable {
    let period: Period
    let route: Route?

    var id: String { period.id }
    var text: String { period.shortText }
}

extension RouteEntry {
    var text: String {
        let dateText = period.date.text(format: "m/d")
        let weekdayText = period.date.weekdaySymbol ?? ""
        return "\(dateText)（\(weekdayText)）\(period.title)"
    }
}
