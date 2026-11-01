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

        var lastCalledFestivalId: String?
        let subject = make(
            festivalRepository: .init(getHandler: { _ in Festival.mock(id: festival.id) }, putHandler: { item in
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

    @Test("LightまたはDarkの一時画像が不正ならFestival Repositoryを更新しない")
    func put_rejectsInvalidVariantBeforeRepositoryWrite() async {
        let lightKey = "temporary/festivals/festival-1/light.jpg"
        let darkKey = "temporary/festivals/festival-1/dark.jpg"
        let oldImage = ImagePath(
            light: "https://cdn.example/old-light.jpg?v=7",
            dark: "https://cdn.example/old-dark.jpg?v=8"
        )
        let current = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "Headquarters",
            base: Coordinate(latitude: 35, longitude: 139),
            image: oldImage
        )
        let pack = FestivalPack(
            festival: Festival(
                id: current.id,
                name: current.name,
                subname: current.subname,
                base: current.base,
                image: ImagePath(light: lightKey, dark: darkKey)
            ),
            checkpoints: [],
            hazardSections: []
        )

        for invalidKey in [lightKey, darkKey] {
            let repository = FestivalRepositorySpy(festivals: [current])
            let imageStorage = ImageStorageClientSpy(validationFailures: [invalidKey])

            await #expect(throws: Error.self) {
                try await withDependencies {
                    $0[FestivalRepositoryKey.self] = repository
                    $0[CheckpointRepositoryKey.self] = CheckpointRepositoryMock(queryHandler: { _ in [] })
                    $0[HazardSectionRepositoryKey.self] = HazardSectionRepositoryMock(queryHandler: { _ in [] })
                    $0[ImageStorageClientKey.self] = imageStorage
                } operation: {
                    try await FestivalUsecase().put(pack, user: .headquarter(current.id))
                }
            }

            #expect(await repository.putItems.isEmpty)
            #expect(await repository.storedFestival(id: current.id)?.image == oldImage)
            #expect(await imageStorage.publishCalls.isEmpty)
        }
    }

    @Test("無関係なtemporary path・別variant・外部URLではFestivalを更新しない")
    func put_rejectsUntrustedImagePathsWithoutChangingStoredImage() async {
        let oldImage = ImagePath(
            light: "https://cdn.example/old-light.jpg?v=7",
            dark: "https://cdn.example/old-dark.jpg?v=8"
        )
        let current = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "Headquarters",
            base: Coordinate(latitude: 35, longitude: 139),
            image: oldImage
        )
        for imagePath in [
            "temporary/festivals/another/light.jpg",
            "temporary/festivals/festival-1/dark.jpg",
            "https://external.example/image.jpg"
        ] {
            let repository = FestivalRepositorySpy(festivals: [current])
            let imageStorage = ImageStorageClientSpy()
            let pack = FestivalPack(
                festival: Festival(
                    id: current.id,
                    name: current.name,
                    subname: current.subname,
                    base: current.base,
                    image: ImagePath(light: imagePath, dark: oldImage.dark)
                ),
                checkpoints: [],
                hazardSections: []
            )

            await #expect(throws: Error.self) {
                try await withDependencies {
                    $0[FestivalRepositoryKey.self] = repository
                    $0[CheckpointRepositoryKey.self] = CheckpointRepositoryMock(queryHandler: { _ in [] })
                    $0[HazardSectionRepositoryKey.self] = HazardSectionRepositoryMock(queryHandler: { _ in [] })
                    $0[ImageStorageClientKey.self] = imageStorage
                } operation: {
                    try await FestivalUsecase().put(pack, user: .headquarter(current.id))
                }
            }

            #expect(await repository.putItems.isEmpty)
            #expect(await repository.storedFestival(id: current.id)?.image == oldImage)
            #expect(await imageStorage.publishCalls.isEmpty)
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
