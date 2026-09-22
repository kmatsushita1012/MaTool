import Dependencies
import SQLiteData
import Shared

public protocol SQLiteStoreProtocol<Content>: Sendable {
    associatedtype Content: PrimaryKeyedTable & Sendable & Identifiable

    func fetchAll(from db: Database) throws -> [Content]
    func fetchAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment], from db: Database) throws -> [Content]
    @available(*, deprecated)
    func insert(_ item: Content, at db: Database) throws
    @available(*, deprecated)
    func insert(_ items: [Content], at db: Database) throws
    func upsert(_ item: Content, at db: Database) throws
    func upsert(_ items: [Content], at db: Database) throws
    func deleteAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment], from db: Database) throws
    func deleteAll(_ primaryKeys: some Sequence<some QueryExpression<Content.PrimaryKey>>, from db: Database) throws
    func deleteAll(from db: Database) throws
}

public extension SQLiteStoreProtocol {
    func delete(_ id: Content.PrimaryKey, from db: Database) throws {
        try deleteAll([id], from: db)
    }

    func fetchAll(@QueryFragmentBuilder<Bool> where predicate: (Content.TableColumns) -> [QueryFragment]) async throws -> [Content] {
        @Dependency(\.defaultDatabase) var database
        return try await database.read { db in
            try fetchAll(where: predicate, from: db)
        }
    }
}

public enum FestivalStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<Festival> = DependencyConfiguration.missing("FestivalStore")
}

public enum CheckpointStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<Checkpoint> = DependencyConfiguration.missing("CheckpointStore")
}

public enum HazardSectionStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<HazardSection> = DependencyConfiguration.missing("HazardSectionStore")
}

public enum DistrictStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<District> = DependencyConfiguration.missing("DistrictStore")
}

public enum PerformanceStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<Performance> = DependencyConfiguration.missing("PerformanceStore")
}

public enum PeriodStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<Period> = DependencyConfiguration.missing("PeriodStore")
}

public enum RouteStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<Route> = DependencyConfiguration.missing("RouteStore")
}

public enum PointStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<Point> = DependencyConfiguration.missing("PointStore")
}

public enum PassageStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<RoutePassage> = DependencyConfiguration.missing("PassageStore")
}

public enum FloatLocationStoreKey: DependencyKey {
    public static let liveValue: any SQLiteStoreProtocol<FloatLocation> = DependencyConfiguration.missing("FloatLocationStore")
}
