import Dependencies
import Shared
import Testing
@testable import Backend

struct FestivalUsecaseTest {
    @Test
    func scan_正常() async throws {
        let festivals = [Festival.mock(id: "festival-1")]
        let repository = FestivalRepositoryMock(scanHandler: { festivals })
        let subject = make(
            festivalRepository: repository,
            checkpointRepository: .init(),
            hazardSectionRepository: .init()
        )

        let result = try await subject.scan()

        #expect(result == festivals)
        #expect(repository.scanCallCount == 1)
    }

    @Test
    func get_正常() async throws {
        let festival = Festival.mock(id: "festival-1")
        let checkpoints = [Checkpoint.mock(id: "cp-1", festivalId: festival.id)]
        let hazards = [HazardSection.mock(id: "hz-1", festivalId: festival.id)]
        var lastCalledFestivalId: String?
        let repository = FestivalRepositoryMock(getHandler: { id in
            lastCalledFestivalId = id
            return festival
        })
        let checkpointRepository = CheckpointRepositoryMock(queryHandler: { _ in checkpoints })
        let hazardRepository = HazardSectionRepositoryMock(queryHandler: { _ in hazards })

        let subject = make(
            festivalRepository: repository,
            checkpointRepository: checkpointRepository,
            hazardSectionRepository: hazardRepository
        )

        let result = try await subject.get(festival.id)

        #expect(result.festival == festival)
        #expect(result.checkpoints == checkpoints)
        #expect(result.hazardSections == hazards)
        #expect(lastCalledFestivalId == festival.id)
        #expect(repository.getCallCount == 1)
        #expect(checkpointRepository.queryCallCount == 1)
        #expect(hazardRepository.queryCallCount == 1)
    }

    @Test
    func get_異常_条件() async {
        let subject = make(
            festivalRepository: .init(getHandler: { _ in nil }),
            checkpointRepository: .init(queryHandler: { _ in [] }),
            hazardSectionRepository: .init(queryHandler: { _ in [] })
        )

        await #expect(throws: Error.notFound("指定された祭典が見つかりません。")) {
            _ = try await subject.get("festival-missing")
        }
    }

    @Test
    func put_異常_条件() async {
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

    @Test
    func put_正常() async throws {
        let festival = Festival.mock(id: "festival-1", name: "new")
        let checkpoint = Checkpoint.mock(id: "cp-1", festivalId: festival.id)
        let hazard = HazardSection.mock(id: "hz-1", festivalId: festival.id)
        let pack = FestivalPack.mock(festival: festival, checkpoints: [checkpoint], hazardSections: [hazard])

        var lastCalledFestivalId: String?
        let subject = make(
            festivalRepository: .init(putHandler: { item in
                lastCalledFestivalId = item.id
                return item
            }),
            checkpointRepository: .init(queryHandler: { _ in [] }, postHandler: { $0 }),
            hazardSectionRepository: .init(queryHandler: { _ in [] }, postHandler: { $0 })
        )

        let result = try await subject.put(pack, user: .headquarter(festival.id))

        #expect(lastCalledFestivalId == festival.id)
        #expect(result.festival == festival)
        #expect(result.checkpoints == [checkpoint])
        #expect(result.hazardSections == [hazard])
    }
}

private extension FestivalUsecaseTest {
    func make(
        festivalRepository: FestivalRepositoryMock = .init(),
        checkpointRepository: CheckpointRepositoryMock = .init(),
        hazardSectionRepository: HazardSectionRepositoryMock = .init()
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
