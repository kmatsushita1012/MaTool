#if !canImport(SQLiteData)
import Foundation

// Lambda shares the domain model without compiling SQLiteData's table macros.

// MARK: - Route
public struct Route: Entity, Identifiable {
    public let id: String
    public let districtId: District.ID
    public let periodId: Period.ID
    public var visibility: Visibility = .all
    public var description: String?

    public init(
        id: Self.ID = UUID().uuidString,
        districtId: District.ID,
        periodId: Period.ID,
        visibility: Visibility = .all,
        description: String? = nil
    ) {
        self.id = id
        self.districtId = districtId
        self.periodId = periodId
        self.visibility = visibility
        self.description = description
    }
}

// MARK: - Point
public struct Point: Entity, Identifiable {
    public let id: String
    public let routeId: Route.ID
    public var coordinate: Coordinate
    public var time: SimpleTime?
    public var checkpointId: Checkpoint.ID?
    public var performanceId: Performance.ID?
    public var anchor: Anchor?
    public var index: Int
    public var isBoundary: Bool

    public init(
        id: Self.ID = UUID().uuidString,
        routeId: Route.ID,
        coordinate: Coordinate,
        time: SimpleTime? = nil,
        checkpointId: Checkpoint.ID? = nil,
        performanceId: Performance.ID? = nil,
        anchor: Anchor? = nil,
        index: Int = 0,
        isBoundary: Bool = false
    ) {
        self.id = id
        self.routeId = routeId
        self.coordinate = coordinate
        self.time = time
        self.checkpointId = checkpointId
        self.performanceId = performanceId
        self.anchor = anchor
        self.index = index
        self.isBoundary = isBoundary
    }
}

// MARK: - RoutePassage
public struct RoutePassage: Entity, Identifiable {
    public let id: String
    public let routeId: Route.ID
    public let districtId: District.ID?
    public var memo: String?
    public var order: Int

    public init(
        id: Self.ID = UUID().uuidString,
        routeId: Route.ID,
        districtId: District.ID? = nil,
        memo: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.routeId = routeId
        self.districtId = districtId
        self.memo = memo
        self.order = order
    }
}

public enum Anchor: String, Entity {
    case start
    case end
    case rest
}

public enum Visibility: String, Entity {
    case admin
    case route
    case all
}

extension Visibility: CaseIterable {}

extension Visibility: Identifiable {
    public var id: Self { self }
}

// MARK: - Period
public struct Period: Entity, Identifiable {
    public let id: String
    public let festivalId: Festival.ID
    public let date: SimpleDate
    public var title: String
    public var start: SimpleTime
    public var end: SimpleTime

    public init(
        id: String = UUID().uuidString,
        festivalId: Festival.ID = "",
        title: String = "",
        date: SimpleDate,
        start: SimpleTime = .now,
        end: SimpleTime = .now
    ) {
        self.id = id
        self.festivalId = festivalId
        self.title = title
        self.date = date
        self.start = start
        self.end = end
    }
}

extension Period: Comparable {
    public static func < (lhs: Period, rhs: Period) -> Bool {
        Date.combine(date: lhs.date, time: lhs.start) < Date.combine(date: rhs.date, time: rhs.start)
    }
}

public extension Period {
    func contains(_ datetime: Date) -> Bool {
        let startDateTime = Date.combine(date: date, time: start)
        let endDateTime = Date.combine(date: date, time: end)
        return startDateTime <= datetime && datetime <= endDateTime
    }

    func before(_ datetime: Date) -> Bool {
        datetime <= Date.combine(date: date, time: start)
    }

    func priority(now: Date) -> (Int, TimeInterval) {
        let startDateTime = Date.combine(date: date, time: start)
        let endDateTime = Date.combine(date: date, time: end)
        if contains(now) {
            return (0, 0)
        }
        if startDateTime > now {
            return (1, startDateTime.timeIntervalSince(now))
        }
        return (2, now.timeIntervalSince(endDateTime))
    }
}

// MARK: - District
public struct District: Entity, Identifiable {
    public let id: String
    public var name: String
    public let festivalId: Festival.ID
    public var order: Int
    public var group: String?
    public var description: String?
    public var base: Coordinate?
    public var area: [Coordinate]
    public var image: ImagePath
    public var visibility: Visibility
    public var isEditable: Bool

    public init(
        id: String,
        name: String,
        festivalId: String,
        order: Int = 0,
        group: String? = nil,
        description: String? = nil,
        base: Coordinate? = nil,
        area: [Coordinate] = [],
        image: ImagePath = .init(),
        visibility: Visibility = .all,
        isEditable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.festivalId = festivalId
        self.order = order
        self.group = group
        self.description = description
        self.base = base
        self.area = area
        self.image = image
        self.visibility = visibility
        self.isEditable = isEditable
    }
}

public struct Performance: Entity {
    public let id: String
    public var name: String = ""
    public let districtId: District.ID
    public var performer: String = ""
    public var description: String?

    public init(
        id: String,
        name: String = "",
        districtId: District.ID,
        performer: String = "",
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.districtId = districtId
        self.performer = performer
        self.description = description
    }
}

extension Performance: Identifiable {}

// MARK: - Festival
public struct Festival: Entity, Identifiable {
    public let id: String
    public var name: String
    public var subname: String
    public var description: String?
    public var prefecture: String
    public var city: String
    public var base: Coordinate
    public var image: ImagePath

    public init(
        id: String,
        name: String,
        subname: String,
        description: String? = nil,
        prefecture: String = "",
        city: String = "",
        base: Coordinate,
        image: ImagePath = .init()
    ) {
        self.id = id
        self.name = name
        self.subname = subname
        self.description = description
        self.prefecture = prefecture
        self.city = city
        self.base = base
        self.image = image
    }
}

public struct Checkpoint: Entity, Identifiable {
    public let id: String
    public let festivalId: Festival.ID
    public var name: String
    public var description: String? = nil

    public init(id: String, name: String = "", festivalId: Festival.ID, description: String? = nil) {
        self.id = id
        self.name = name
        self.festivalId = festivalId
        self.description = description
    }
}

public struct HazardSection: Entity, Identifiable {
    public let id: String
    public var title: String
    public let festivalId: Festival.ID
    public var coordinates: [Coordinate]

    public init(id: String, title: String = "", festivalId: Festival.ID, coordinates: [Coordinate] = []) {
        self.id = id
        self.title = title
        self.festivalId = festivalId
        self.coordinates = coordinates
    }
}

// MARK: - FloatLocation
public struct FloatLocation: Entity, Identifiable {
    public let id: String
    public let districtId: String
    public let coordinate: Coordinate
    public let timestamp: Date

    public init(id: String, districtId: District.ID, coordinate: Coordinate, timestamp: Date = .now) {
        self.id = id
        self.districtId = districtId
        self.coordinate = coordinate
        self.timestamp = timestamp
    }
}
#endif
