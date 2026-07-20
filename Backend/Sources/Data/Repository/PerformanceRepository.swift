import Dependencies
import Shared

fileprivate typealias PRecord = Record<Performance>

enum PerformanceRepositoryKey: DependencyKey {
    static let liveValue: any PerformanceRepositoryProtocol = PerformanceRepository()
}

extension DependencyValues {
    var performanceRepository: any PerformanceRepositoryProtocol {
        get { self[PerformanceRepositoryKey.self] }
        set { self[PerformanceRepositoryKey.self] = newValue }
    }
}

protocol PerformanceRepositoryProtocol: Repository where Content == Performance {
    func get(id: String) async throws -> Performance?
    func query(by festivalId: String) async throws -> [Performance]
    func put(_ item: Performance) async throws -> Performance
    func post(_ item: Performance) async throws -> Performance
    func delete(_ item: Performance) async throws -> Void
}

struct PerformanceRepository: PerformanceRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var factory
        self.store = factory("matool")
    }

    func get(id: String) async throws -> Performance? {
        let keys = PRecord.makeKeys(id)
        let records = try await store.query(indexName: keys.indexName, queryConditions: [keys.pk, keys.sk], as: PRecord.self)
        return records.first?.content
    }

    func query(by districtId: String) async throws -> [Performance] {
        let keys = PRecord.makeKeys(districtId: districtId)
        let records = try await store.query(queryConditions: [keys.pk, keys.sk], as: PRecord.self)
        return records.map(\.content)
    }

    func put(_ item: Performance) async throws -> Performance {
        let record = PRecord(item)
        try await store.put(record)
        return record.content
    }

    func post(_ item: Performance) async throws -> Performance {
        let record = PRecord(item)
        try await store.put(record)
        return record.content
    }
    
    func delete(_ item: Performance) async throws -> Void {
        let keys = PRecord.makeKeys(item.id, districtId: item.districtId)
        try await store.delete(pk: keys.pk, sk: keys.sk)
    }
}

extension Record where Content == Performance {
    init(_ item: Performance) {
    let keys = Self.makeKeys(item.id, districtId: item.districtId)
        self.init(pk: keys.pk, sk: keys.sk, type: Self.type, content: item)
    }

    static func makeKeys(_ id: String, districtId: String) -> (pk: String, sk: String) {
        (pk: "\(pkPrefix)\(districtId)", sk: "\(skPrefix)\(id)")
    }

    static func makeKeys(districtId: String) -> (pk: QueryCondition, sk: QueryCondition) {
        (pk: .equals("pk", "\(pkPrefix)\(districtId)"), sk: .beginsWith("sk", "\(skPrefix)"))
    }

    static func makeKeys(_ id: String) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        (indexName: "index-\(type)", pk: .equals("type", "\(type)"), sk: .equals("sk", "\(skPrefix)\(id)"))
    }

    static let pkPrefix = "DISTRICT#"
    static let skPrefix = "PERFORMANCE#"
    static let type = String(describing: Performance.self).uppercased()
}
