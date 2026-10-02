import Dependencies
import Shared

protocol FestivalPackRepositoryProtocol: Sendable {
    func put(_ pack: FestivalPack) async throws -> FestivalPack
}

enum FestivalPackRepositoryKey: DependencyKey {
    static let liveValue: FestivalPackRepositoryProtocol = FestivalPackRepository()
}

struct FestivalPackRepository: FestivalPackRepositoryProtocol {
    private let store: DataStore

    init() {
        @Dependency(\.dataStoreFactory) var storeFactory
        self.store = storeFactory("matool")
    }

    func put(_ pack: FestivalPack) async throws -> FestivalPack {
        async let checkpointsTask = store.query(
            queryConditions: [
                .equals("pk", "FESTIVAL#\(pack.festival.id)"),
                .beginsWith("sk", "CHECKPOINT#")
            ],
            as: Record<Checkpoint>.self
        )
        async let hazardSectionsTask = store.query(
            queryConditions: [
                .equals("pk", "FESTIVAL#\(pack.festival.id)"),
                .beginsWith("sk", "HAZARDSECTION#")
            ],
            as: Record<HazardSection>.self
        )
        let (checkpointRecords, hazardSectionRecords) = try await (checkpointsTask, hazardSectionsTask)

        let checkpointMutations = try mutations(
            old: checkpointRecords.map(\.content),
            new: pack.checkpoints,
            makeMutation: { try DataStoreMutation.put(checkpointRecord($0)) },
            makeDeletion: { .delete(pk: "FESTIVAL#\($0.festivalId)", sk: "CHECKPOINT#\($0.id)") }
        )
        let hazardSectionMutations = try mutations(
            old: hazardSectionRecords.map(\.content),
            new: pack.hazardSections,
            makeMutation: { try DataStoreMutation.put(hazardSectionRecord($0)) },
            makeDeletion: { .delete(pk: "FESTIVAL#\($0.festivalId)", sk: "HAZARDSECTION#\($0.id)") }
        )
        let mutations = [try DataStoreMutation.put(festivalRecord(pack.festival))]
            + checkpointMutations
            + hazardSectionMutations

        try await store.transactWrite(mutations)
        return pack
    }
}

private func mutations<Element: Identifiable & Equatable & Sendable>(
    old: [Element],
    new: [Element],
    makeMutation: (Element) throws -> DataStoreMutation,
    makeDeletion: (Element) -> DataStoreMutation
) throws -> [DataStoreMutation] {
    let oldByID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let newByID = Dictionary(new.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    guard newByID.count == new.count else {
        throw DomainError.unknown("同じIDの子要素が複数含まれています。")
    }

    var updates: [DataStoreMutation] = []
    for item in new {
        guard oldByID[item.id] != item else { continue }
        updates.append(try makeMutation(item))
    }
    let deletions = old.compactMap { item -> DataStoreMutation? in
        guard newByID[item.id] == nil else { return nil }
        return makeDeletion(item)
    }
    return updates + deletions
}

private func festivalRecord(_ item: Festival) -> Record<Festival> {
    Record(pk: "FESTIVAL#\(item.id)", sk: "METADATA", content: item)
}

private func checkpointRecord(_ item: Checkpoint) -> Record<Checkpoint> {
    Record(pk: "FESTIVAL#\(item.festivalId)", sk: "CHECKPOINT#\(item.id)", type: "CHECKPOINT", content: item)
}

private func hazardSectionRecord(_ item: HazardSection) -> Record<HazardSection> {
    Record(pk: "FESTIVAL#\(item.festivalId)", sk: "HAZARDSECTION#\(item.id)", content: item)
}
