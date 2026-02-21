import Dependencies
import Shared
import Testing
@testable import Backend

struct FestivalUsecaseTest {
    @Test
    func get_returnsFestivalPack() async throws {
        let festival = Festival.mock(id: "festival-1")
        let checkpoints = [Checkpoint.mock(id: "cp-1", festivalId: festival.id)]
        let hazards = [HazardSection.mock(id: "hz-1", festivalId: festival.id)]

        let subject = make(
            festivalRepository: .init(getHandler: { _ in festival }),
            checkpointRepository: .init(queryHandler: { _ in checkpoints }),
            hazardSectionRepository: .init(queryHandler: { _ in hazards })
        )

        let result = try await subject.get(festival.id)

        #expect(result.festival == festival)
        #expect(result.checkpoints == checkpoints)
        #expect(result.hazardSections == hazards)
    }

    @Test
    func put_unauthorized_throws() async {
        let pack = FestivalPack.mock(festival: .mock(id: "festival-1"))
        let subject = make(
            festivalRepository: .init(),
            checkpointRepository: .init(),
            hazardSectionRepository: .init()
        )

        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await subject.put(pack, user: .guest)
        }
    }
}

private extension FestivalUsecaseTest {
    func make(
        festivalRepository: FestivalRepositoryMock,
        checkpointRepository: CheckpointRepositoryMock,
        hazardSectionRepository: HazardSectionRepositoryMock
    ) -> FestivalUsecase {
        withDependencies {
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[CheckpointRepositoryKey.self] = checkpointRepository
            $0[HazardSectionRepositoryKey.self] = hazardSectionRepository
        } operation: {
            FestivalUsecase()
        }
    }
}
