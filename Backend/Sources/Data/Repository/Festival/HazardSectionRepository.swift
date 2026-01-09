import Dependencies
import Shared

fileprivate typealias HSRecord = Record<HazardSection>

// MARK: - Dependencies
enum HazardSectionRepositoryKey: DependencyKey {
    static let liveValue: any HazardSectionRepositoryProtocol = HazardSectionRepository()
}
extension DependencyValues {
    var hazardSectionRepository: any HazardSectionRepositoryProtocol {
        get { self[HazardSectionRepositoryKey.self] }
        set { self[HazardSectionRepositoryKey.self] = newValue }
    }
}

// MARK: - Protocol
protocol HazardSectionRepositoryProtocol: Repository where Content == HazardSection {
    func get(id: String) async throws -> HazardSection?
    func query(by festivalId: String) async throws -> [HazardSection]
    func put(_ item: HazardSection) async throws -> HazardSection
    func post(_ item: HazardSection) async throws -> HazardSection
    func delete(_ id: String) async throws
}

// MARK: - Repository
struct HazardSectionRepository: HazardSectionRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }

    func get(id: String) async throws -> HazardSection? {
        let keys = HSRecord.makeKeys(id)
        let record = try await store.query(indexName: keys.indexName, queryConditions: [ keys.pk, keys.sk ], as: HSRecord.self).first
        return record?.content
    }

    func query(by festivalId: String) async throws -> [HazardSection] {
        let keys = HSRecord.makeKeys(festivalId: festivalId)
        let records = try await store.query(
            queryConditions: [ keys.pk, keys.sk ],
            as: HSRecord.self
        )
        return records.map { $0.content }
    }

    func put(_ item: HazardSection) async throws -> HazardSection {
        let record = HSRecord(item)
        try await store.put(record)
        return item
    }

    func post(_ item: HazardSection) async throws -> HazardSection {
        let record = HSRecord(item)
        try await store.put(record)
        return item
    }

    func delete(_ id: String) async throws {
        guard let target = try await get(id: id) else { return }
        let keys = HSRecord.makeKeys(target.id, festivalId: target.festivalId)
        try await store.delete(pk: keys.pk, sk: keys.sk)
    }
}

fileprivate extension Record where Content == HazardSection {
    init(_ item: HazardSection) {
        let keys = Self.makeKeys(item.id, festivalId: item.festivalId)
        self.init(pk: keys.pk, sk: keys.sk, content: item)
    }
    
    static func makeKeys(_ id: String, festivalId: String) -> (pk: String, sk: String) {
        return (pk: "\(pkPrefix)\(festivalId)", sk: "\(skPrefix)\(id)")
    }

    static func makeKeys(_ id: String) -> (indexName: String, pk: QueryCondition, sk: QueryCondition) {
        return (indexName: indexName, pk: .equals("type", "\(type)"), sk: .equals("sk", "\(skPrefix)\(id)"))
    }
    
    static func makeKeys(festivalId : String) -> (pk: QueryCondition, sk: QueryCondition) {
        return (pk: .equals("pk", "\(pkPrefix)\(festivalId)"), sk: .beginsWith("sk", skPrefix))
    }

    static let pkPrefix: String = "FESTIVAL#"
    static let skPrefix: String = "HAZARDSECTION#"
    static let type = String(describing: HazardSection.self).uppercased()
    static let indexName = "index-\(type)"
}

