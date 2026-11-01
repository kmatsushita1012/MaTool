import Dependencies
import Foundation
import Shared
@testable import Backend

extension FestivalPackScopeRouterTest {
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

        let festivalRepository = FestivalRepositoryMock(getHandler: { _ in store.snapshot().festival }, putHandler: { item in
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

final class FestivalPackStore: @unchecked Sendable {
    private let lock = NSLock()
    private var festival: Festival
    private var storedCheckpoints: [Checkpoint]
    private var storedHazardSections: [HazardSection]

    init(festival: Festival, checkpoints: [Checkpoint], hazardSections: [HazardSection]) {
        self.festival = festival
        self.storedCheckpoints = checkpoints
        self.storedHazardSections = hazardSections
    }

    func snapshot() -> FestivalPackSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return FestivalPackSnapshot(festival: festival, checkpoints: storedCheckpoints, hazardSections: storedHazardSections)
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

struct FestivalPackSnapshot: Equatable {
    let festival: Festival
    let checkpoints: [Checkpoint]
    let hazardSections: [HazardSection]
}
