import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct FestivalPackScopeRouterTest {
    @Test
    func put_異常_チェックポイントが別祭典_書き込み前に拒否() async throws {
        let harness = makeHarness()
        let original = harness.store.snapshot()
        let pack = FestivalPack.mock(
            festival: .mock(id: "festival-1", name: "updated"),
            checkpoints: [.mock(id: "checkpoint-2", festivalId: "festival-2")]
        )

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-1")))

        #expect(response.statusCode == 400)
        #expect(response.body.contains("祭典と子要素の祭典IDが一致しません。"))
        #expect(harness.store.snapshot() == original)
        #expect(harness.festivalRepository.putCount == 0)
        #expect(harness.checkpointRepository.queryCallCount == 0)
        #expect(harness.checkpointRepository.postCallCount == 0)
        #expect(harness.checkpointRepository.putCallCount == 0)
        #expect(harness.checkpointRepository.deleteCallCount == 0)
        #expect(harness.hazardSectionRepository.queryCallCount == 0)
        #expect(harness.hazardSectionRepository.postCallCount == 0)
        #expect(harness.hazardSectionRepository.putCallCount == 0)
        #expect(harness.hazardSectionRepository.deleteCallCount == 0)
    }

    @Test
    func put_異常_危険区間が別祭典_書き込み前に拒否() async throws {
        let harness = makeHarness()
        let original = harness.store.snapshot()
        let pack = FestivalPack.mock(
            festival: .mock(id: "festival-1", name: "updated"),
            hazardSections: [.mock(id: "hazard-2", festivalId: "festival-2")]
        )

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-1")))

        #expect(response.statusCode == 400)
        #expect(response.body.contains("祭典と子要素の祭典IDが一致しません。"))
        #expect(harness.store.snapshot() == original)
        #expect(harness.festivalRepository.putCount == 0)
        #expect(harness.checkpointRepository.queryCallCount == 0)
        #expect(harness.hazardSectionRepository.queryCallCount == 0)
        #expect(harness.checkpointRepository.postCallCount + harness.checkpointRepository.putCallCount + harness.checkpointRepository.deleteCallCount == 0)
        #expect(harness.hazardSectionRepository.postCallCount + harness.hazardSectionRepository.putCallCount + harness.hazardSectionRepository.deleteCallCount == 0)
    }

    @Test
    func put_異常_URLと本文の祭典が不一致_書き込み前に拒否() async throws {
        let harness = makeHarness()
        let original = harness.store.snapshot()
        let pack = FestivalPack.mock(festival: .mock(id: "festival-2", name: "updated"))

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-2")))

        #expect(response.statusCode == 400)
        #expect(response.body.contains("URLの祭典IDと送信データの祭典IDが一致しません。"))
        #expect(harness.store.snapshot() == original)
        #expect(harness.festivalRepository.putCount == 0)
        #expect(harness.checkpointRepository.queryCallCount == 0)
        #expect(harness.hazardSectionRepository.queryCallCount == 0)
        #expect(harness.checkpointRepository.postCallCount + harness.checkpointRepository.putCallCount + harness.checkpointRepository.deleteCallCount == 0)
        #expect(harness.hazardSectionRepository.postCallCount + harness.hazardSectionRepository.putCallCount + harness.hazardSectionRepository.deleteCallCount == 0)
    }

    @Test
    func put_異常_本部権限が別祭典_書き込み前に拒否() async throws {
        let harness = makeHarness()
        let original = harness.store.snapshot()
        let pack = FestivalPack.mock(
            festival: .mock(id: "festival-1", name: "updated"),
            checkpoints: [.mock(id: "checkpoint-1", festivalId: "festival-1", name: "updated")]
        )

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-2")))

        #expect(response.statusCode == 401)
        #expect(response.body.contains("アクセス権限がありません。"))
        #expect(harness.store.snapshot() == original)
        #expect(harness.festivalRepository.putCount == 0)
        #expect(harness.checkpointRepository.queryCallCount == 0)
        #expect(harness.hazardSectionRepository.queryCallCount == 0)
        #expect(harness.checkpointRepository.postCallCount + harness.checkpointRepository.putCallCount + harness.checkpointRepository.deleteCallCount == 0)
        #expect(harness.hazardSectionRepository.postCallCount + harness.hazardSectionRepository.putCallCount + harness.hazardSectionRepository.deleteCallCount == 0)
    }

    @Test
    func put_正常_同じ祭典の子要素を更新して状態を保存() async throws {
        let harness = makeHarness()
        let pack = FestivalPack.mock(
            festival: .mock(id: "festival-1", name: "festival-updated"),
            checkpoints: [.mock(id: "checkpoint-1", festivalId: "festival-1", name: "checkpoint-updated")],
            hazardSections: [.mock(id: "hazard-1", festivalId: "festival-1", title: "hazard-updated")]
        )

        let response = await harness.handle(try request(pack, pathFestivalId: "festival-1", user: .headquarter("festival-1")))
        let responsePack = try FestivalPack.from(response.body)
        let saved = harness.store.snapshot()

        #expect(response.statusCode == 200)
        #expect(responsePack == pack)
        #expect(saved.festival == pack.festival)
        #expect(saved.checkpoints == pack.checkpoints)
        #expect(saved.hazardSections == pack.hazardSections)
        #expect(harness.festivalRepository.putCount == 1)
        #expect(harness.checkpointRepository.queryCallCount == 1)
        #expect(harness.checkpointRepository.putCallCount == 1)
        #expect(harness.hazardSectionRepository.queryCallCount == 1)
        #expect(harness.hazardSectionRepository.putCallCount == 1)
    }
}

private extension FestivalPackScopeRouterTest {
    struct Harness {
        let app: Application
        let store: FestivalPackStore
        let festivalRepository: FestivalRepositoryMock
        let checkpointRepository: CheckpointRepositoryMock
        let hazardSectionRepository: HazardSectionRepositoryMock

        func handle(_ request: Application.Request) async -> Application.Response {
            await withDependencies {
                $0[FestivalUsecaseKey.self] = FestivalUsecase()
                $0[FestivalControllerKey.self] = FestivalController()
                $0[FestivalRepositoryKey.self] = festivalRepository
                $0[CheckpointRepositoryKey.self] = checkpointRepository
                $0[HazardSectionRepositoryKey.self] = hazardSectionRepository
            } operation: {
                await app.handle(request)
            }
        }
    }

    func makeHarness() -> Harness {
        let festival = Festival.mock(id: "festival-1", name: "festival-original")
        let checkpoint = Checkpoint.mock(id: "checkpoint-1", festivalId: festival.id, name: "checkpoint-original")
        let hazard = HazardSection.mock(id: "hazard-1", festivalId: festival.id, title: "hazard-original")
        let store = FestivalPackStore(festival: festival, checkpoints: [checkpoint], hazardSections: [hazard])

        let festivalRepository = FestivalRepositoryMock(putHandler: { item in
            store.save(item)
            return item
        })
        let checkpointRepository = CheckpointRepositoryMock(
            queryHandler: { store.checkpoints(for: $0) },
            postHandler: { item in
                store.save(item)
                return item
            },
            putHandler: { item in
                store.save(item)
                return item
            },
            deleteHandler: { store.delete($0) }
        )
        let hazardSectionRepository = HazardSectionRepositoryMock(
            queryHandler: { store.hazardSections(for: $0) },
            postHandler: { item in
                store.save(item)
                return item
            },
            putHandler: { item in
                store.save(item)
                return item
            },
            deleteHandler: { store.delete($0) }
        )

        let usecase = withDependencies {
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[CheckpointRepositoryKey.self] = checkpointRepository
            $0[HazardSectionRepositoryKey.self] = hazardSectionRepository
        } operation: {
            FestivalUsecase()
        }
        let app = withDependencies {
            $0[FestivalUsecaseKey.self] = usecase
            $0[FestivalControllerKey.self] = FestivalController()
        } operation: {
            Application { FestivalPackPutTestRouter() }
        }

        return Harness(
            app: app,
            store: store,
            festivalRepository: festivalRepository,
            checkpointRepository: checkpointRepository,
            hazardSectionRepository: hazardSectionRepository
        )
    }

    func request(_ pack: FestivalPack, pathFestivalId: String, user: UserRole) throws -> Application.Request {
        var request = Application.Request.make(
            method: .put,
            path: "/festivals/\(pathFestivalId)",
            body: try pack.toString()
        )
        request.user = user
        return request
    }
}

private struct FestivalPackPutTestRouter: Router {
    @Dependency(FestivalControllerKey.self) var controller

    func body(_ app: Application) {
        app.put(path: "/festivals/:festivalId", controller.put)
    }
}

private final class FestivalPackStore: @unchecked Sendable {
    private let lock = NSLock()
    private var festival: Festival
    private var storedCheckpoints: [Checkpoint]
    private var storedHazardSections: [HazardSection]

    init(festival: Festival, checkpoints: [Checkpoint], hazardSections: [HazardSection]) {
        self.festival = festival
        self.storedCheckpoints = checkpoints
        self.storedHazardSections = hazardSections
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(festival: festival, checkpoints: storedCheckpoints, hazardSections: storedHazardSections)
    }

    func checkpoints(for festivalId: String) -> [Checkpoint] {
        lock.lock()
        defer { lock.unlock() }
        return storedCheckpoints.filter { $0.festivalId == festivalId }
    }

    func hazardSections(for festivalId: String) -> [HazardSection] {
        lock.lock()
        defer { lock.unlock() }
        return storedHazardSections.filter { $0.festivalId == festivalId }
    }

    func save(_ item: Festival) {
        lock.lock()
        defer { lock.unlock() }
        festival = item
    }

    func save(_ item: Checkpoint) {
        lock.lock()
        defer { lock.unlock() }
        if let index = storedCheckpoints.firstIndex(where: { $0.id == item.id && $0.festivalId == item.festivalId }) {
            storedCheckpoints[index] = item
        } else {
            storedCheckpoints.append(item)
        }
    }

    func save(_ item: HazardSection) {
        lock.lock()
        defer { lock.unlock() }
        if let index = storedHazardSections.firstIndex(where: { $0.id == item.id && $0.festivalId == item.festivalId }) {
            storedHazardSections[index] = item
        } else {
            storedHazardSections.append(item)
        }
    }

    func delete(_ item: Checkpoint) {
        lock.lock()
        defer { lock.unlock() }
        storedCheckpoints.removeAll { $0.id == item.id && $0.festivalId == item.festivalId }
    }

    func delete(_ item: HazardSection) {
        lock.lock()
        defer { lock.unlock() }
        storedHazardSections.removeAll { $0.id == item.id && $0.festivalId == item.festivalId }
    }
}

private struct Snapshot: Equatable {
    let festival: Festival
    let checkpoints: [Checkpoint]
    let hazardSections: [HazardSection]
}
