import SQLiteData
import CasePaths

public extension FetchAll where Element == District {
    init(festivalId: Festival.ID) {
        self.init(District.where { $0.festivalId.eq(festivalId) }.order(by: \.order))
    }
}

public extension FetchAll where Element == Point {
    init(routeId: Route.ID) {
        self.init(Point.where { $0.routeId.eq(routeId) }.order(by: \.index))
    }
}

public extension FetchAll where Element == RoutePassage {
    init(routeId: Route.ID) {
        self.init(RoutePassage.where { $0.routeId.eq(routeId) }.order(by: \.order))
    }
}

public extension FetchAll where Element == HazardSection {
    init(festivalId: Festival.ID) {
        self.init(HazardSection.where { $0.festivalId.eq(festivalId) })
    }
}

public extension FetchOne where Value == District {
    init(_ value: District) {
        self.init(wrappedValue: value, District.find(value.id))
    }
    
    init?(id: District.ID) {
        guard let defaultValue = FetchOne<District?>(District.find(id)).wrappedValue else {
            return nil
        }
        self.init(wrappedValue: defaultValue , District.find(id))
    }
}

public extension FetchOne where Value == Festival {
    init(_ value: Festival) {
        self.init(wrappedValue: value, Festival.find(value.id))
    }
    
    init?(id: Festival.ID) {
        guard let defaultValue = FetchOne<Festival?>(Festival.find(id)).wrappedValue else {
            return nil
        }
        self.init(wrappedValue: defaultValue , Festival.find(id))
    }
}


public extension FetchOne where Value == Period {
    init(_ value: Period) {
        self.init(wrappedValue: value, Period.find(value.id))
    }
    
    init?(id: Period.ID) {
        guard let defaultValue = FetchOne<Period?>(Period.find(id)).wrappedValue else {
            return nil
        }
        self.init(wrappedValue: defaultValue , Period.find(id))
    }
}

extension QueryExpression
where QueryValue: QueryRepresentable & QueryExpression,
      QueryValue.QueryValue == QueryValue {

    public func eq(_ other: QueryValue?) -> some QueryExpression<Bool> {
        let valuesForIn: [QueryValue] = other.map { [$0] } ?? []
        return self.in(valuesForIn)
    }
}
