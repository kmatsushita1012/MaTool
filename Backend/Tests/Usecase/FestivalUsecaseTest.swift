import Dependencies
import Shared
import Testing
@testable import Backend

struct FestivalUsecaseTest {
    @Test
    func scan_正常() async throws {
        let festivals = [Festival.mock(id: "festival-1")]
        let repository = FestivalRepositoryMock(scanHandler: { festivals })
        let subject = make(festivalRepository: repository)

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
    func get_異常_祭典未登録() async {
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
    func put_異常_権限不一致() async {
        let pack = FestivalPack.mock(festival: .mock(id: "festival-1"))
        let subject = make()

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
        let packRepository = FestivalPackRepositoryMock(putHandler: { $0 })
        let subject = make(packRepository: packRepository)

        let result = try await subject.put(pack, user: .headquarter(festival.id))

        #expect(result == pack)
        #expect(packRepository.putCallCount == 1)
        #expect(packRepository.lastPack == pack)
    }

    @Test
    func put_異常_保存エラーを透過() async {
        let festival = Festival.mock(id: "festival-1")
        let packRepository = FestivalPackRepositoryMock(putHandler: { _ in throw TestError.intentional })
        let subject = make(packRepository: packRepository)

        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(.mock(festival: festival), user: .headquarter(festival.id))
        }
    }

    @Test
    func get_異常_依存エラーを透過() async {
        let subject = make(festivalRepository: .init(getHandler: { _ in throw TestError.intentional }))

        await #expect(throws: TestError.intentional) {
            _ = try await subject.get("festival-1")
        }
    }
}

private extension FestivalUsecaseTest {
    func make(
        festivalRepository: FestivalRepositoryMock = .init(),
        checkpointRepository: CheckpointRepositoryMock = .init(),
        hazardSectionRepository: HazardSectionRepositoryMock = .init(),
        packRepository: FestivalPackRepositoryMock = .init()
    ) -> FestivalUsecase {
        withDependencies {
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[CheckpointRepositoryKey.self] = checkpointRepository
            $0[HazardSectionRepositoryKey.self] = hazardSectionRepository
            $0[FestivalPackRepositoryKey.self] = packRepository
        } operation: {
            FestivalUsecase()
        }
    }
}

private final class FestivalPackRepositoryMock: FestivalPackRepositoryProtocol, @unchecked Sendable {
    private let putHandler: ((FestivalPack) throws -> FestivalPack)?
    private(set) var putCallCount = 0
    private(set) var lastPack: FestivalPack?

    init(putHandler: ((FestivalPack) throws -> FestivalPack)? = nil) {
        self.putHandler = putHandler
    }

    func put(_ pack: FestivalPack) async throws -> FestivalPack {
        putCallCount += 1
        lastPack = pack
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(pack)
    }
}
