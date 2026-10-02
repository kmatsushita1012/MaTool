import Dependencies
import Shared
import Testing
@testable import Backend

struct FestivalPackRepositoryTest {
    @Test
    func put_異常_差分全体を単一トランザクションに渡す() async {
        let festival = Festival.mock(id: "festival-1", name: "更新後")
        let checkpointToUpdate = Checkpoint.mock(id: "checkpoint-update", festivalId: festival.id, name: "更新後")
        let checkpointToAdd = Checkpoint.mock(id: "checkpoint-add", festivalId: festival.id)
        let oldCheckpoints = [
            Checkpoint.mock(id: checkpointToUpdate.id, festivalId: festival.id, name: "更新前"),
            Checkpoint.mock(id: "checkpoint-delete", festivalId: festival.id)
        ]
        let hazardToUpdate = HazardSection.mock(id: "hazard-update", festivalId: festival.id, title: "更新後")
        let oldHazards = [
            HazardSection.mock(id: hazardToUpdate.id, festivalId: festival.id, title: "更新前"),
            HazardSection.mock(id: "hazard-delete", festivalId: festival.id)
        ]
        let pack = FestivalPack.mock(
            festival: festival,
            checkpoints: [checkpointToUpdate, checkpointToAdd],
            hazardSections: [hazardToUpdate]
        )

        var capturedMutations: [DataStoreMutation] = []
        let store = DataStoreMock(
            queryHandler: { _, _, _, _, _, type in
                if type == Record<Checkpoint>.self {
                    return try encodeForDataStore(oldCheckpoints.map { self.checkpointRecord($0) })
                }
                if type == Record<HazardSection>.self {
                    return try encodeForDataStore(oldHazards.map { self.hazardRecord($0) })
                }
                throw TestError.unimplemented
            },
            transactionWriteHandler: { mutations in
                capturedMutations = mutations
                throw TestError.intentional
            }
        )
        let subject = make(dataStore: store)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(pack)
        }

        #expect(store.transactionWriteCallCount == 1)
        #expect(store.putCallCount == 0)
        #expect(store.deleteCallCount == 0)
        #expect(capturedMutations.count == 6)

        let festivalMutation = capturedMutations.first { $0.key == DataStoreItemKey(pk: "FESTIVAL#\(festival.id)", sk: "METADATA") }
        guard case let .put(festivalData)? = festivalMutation?.operation,
              let festivalRecord = try? decodeRecord(Record<Festival>.self, from: festivalData) else {
            Issue.record("Festival レコードがトランザクションに含まれていません。")
            return
        }
        #expect(festivalRecord.content == festival)

        let updatedCheckpointIDs = capturedMutations.compactMap { mutation -> String? in
            guard case let .put(data) = mutation.operation,
                  let record = try? decodeRecord(Record<Checkpoint>.self, from: data) else { return nil }
            return record.content.id
        }
        #expect(updatedCheckpointIDs == [checkpointToUpdate.id, checkpointToAdd.id])
        let updatedHazardIDs = capturedMutations.compactMap { mutation -> String? in
            guard case let .put(data) = mutation.operation,
                  let record = try? decodeRecord(Record<HazardSection>.self, from: data) else { return nil }
            return record.content.id
        }
        #expect(updatedHazardIDs == [hazardToUpdate.id])
        #expect(capturedMutations.contains { mutation in
            guard case .delete = mutation.operation else { return false }
            return mutation.key == DataStoreItemKey(pk: "FESTIVAL#\(festival.id)", sk: "CHECKPOINT#checkpoint-delete")
        })
        #expect(capturedMutations.contains { mutation in
            guard case .delete = mutation.operation else { return false }
            return mutation.key == DataStoreItemKey(pk: "FESTIVAL#\(festival.id)", sk: "HAZARDSECTION#hazard-delete")
        })
    }
}

private extension FestivalPackRepositoryTest {
    func make(dataStore: DataStoreMock) -> FestivalPackRepository {
        withDependencies {
            $0[DataStoreFactoryKey.self] = { _ in dataStore }
        } operation: {
            FestivalPackRepository()
        }
    }

    func checkpointRecord(_ checkpoint: Checkpoint) -> Record<Checkpoint> {
        Record(
            pk: "FESTIVAL#\(checkpoint.festivalId)",
            sk: "CHECKPOINT#\(checkpoint.id)",
            type: "CHECKPOINT",
            content: checkpoint
        )
    }

    func hazardRecord(_ hazard: HazardSection) -> Record<HazardSection> {
        Record(pk: "FESTIVAL#\(hazard.festivalId)", sk: "HAZARDSECTION#\(hazard.id)", content: hazard)
    }

    func decodeRecord<RecordType: Decodable>(_ type: RecordType.Type, from data: Data) throws -> RecordType {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }
}
