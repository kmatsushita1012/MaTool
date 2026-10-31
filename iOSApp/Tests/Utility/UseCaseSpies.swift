import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

actor FetchDistrictUseCaseSpy: FetchDistrictUseCaseProtocol {
    let pack: DistrictPack
    private(set) var requestedIDs: [District.ID] = []

    init(pack: DistrictPack) { self.pack = pack }

    func callAsFunction(districtId: District.ID) async throws -> DistrictPack {
        requestedIDs.append(districtId)
        return pack
    }
}

final class GetSceneSelectionUseCaseSpy: GetSceneSelectionUseCaseProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var selection: SceneSelection
    private var count = 0

    init(selection: SceneSelection) { self.selection = selection }

    var callCount: Int { lock.withLock { count } }

    func callAsFunction() -> SceneSelection {
        lock.withLock { count += 1 }
        return selection
    }
}

final class LastMainScreenUseCaseSpy: LastMainScreenUseCaseProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: LastMainScreen?
    private var recorded: [LastMainScreen?] = []

    init(value: LastMainScreen? = nil) { stored = value }

    var value: LastMainScreen? { lock.withLock { stored } }
    var savedValues: [LastMainScreen?] { lock.withLock { recorded } }

    func load() -> LastMainScreen? { value }
    func save(_ screen: LastMainScreen?) {
        lock.withLock {
            stored = screen
            recorded.append(screen)
        }
    }
}

actor FailingFestivalListUseCaseSpy: FetchFestivalListUseCaseProtocol {
    private var fetchCalls = 0

    func callAsFunction() async throws -> [Festival] {
        fetchCalls += 1
        throw AppError.be(.network("network"))
    }

    func fetchCallCount() -> Int { fetchCalls }
}

actor FetchRoutePackUseCaseSpy: FetchRoutePackUseCaseProtocol {
    let pack: RoutePack
    private(set) var requestedIDs: [Route.ID] = []

    init(pack: RoutePack) { self.pack = pack }

    func callAsFunction(routeId: Route.ID) async throws -> RoutePack {
        requestedIDs.append(routeId)
        return pack
    }
}

actor PublicMapAdUsecaseSpy: PublicMapAdUsecaseProtocol {
    struct Selection: Sendable {
        let userRole: UserRole
        let districtId: District.ID
        let hasDisplayableContent: Bool
    }

    private(set) var sessionPreparations = 0
    private(set) var selections: [Selection] = []

    func prepareSession() async { sessionPreparations += 1 }
    func handleDistrictSelectionResult(
        userRole: UserRole, districtId: District.ID, hasDisplayableContent: Bool
    ) async {
        selections.append(.init(
            userRole: userRole,
            districtId: districtId,
            hasDisplayableContent: hasDisplayableContent
        ))
    }
}

actor DistrictLoadSpy: LoadDistrictStateUseCaseProtocol {
    private let response: LaunchDistrictPack
    private var periodId: Period.ID?

    init(response: LaunchDistrictPack) { self.response = response }

    func callAsFunction(
        districtId: District.ID,
        periodId: Period.ID?,
        appState: Shared<AppState?>
    ) async throws -> LaunchDistrictPack {
        self.periodId = periodId
        return response
    }

    func receivedPeriodId() -> Period.ID? { periodId }
}

struct SupersedingRouteDataFetcherSpy: RouteDataFetcherProtocol {
    let appState: Shared<AppState?>
    let response: RoutePack

    func fetchAll(districtID: District.ID, query: Query) async throws -> [Route] {
        throw CancellationError()
    }

    func fetch(routeID: Route.ID) async throws -> RoutePack {
        appState.withLock { current in
            guard var updated = current else { return }
            updated.routeLoadRequestId = UUID()
            current = updated
        }
        return response
    }

    func update(_ route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack {
        throw CancellationError()
    }

    func create(districtID: District.ID, route: Route, points: [Point], passages: [RoutePassage]) async throws -> RoutePack {
        throw CancellationError()
    }

    func delete(_ routeID: Route.ID) async throws {
        throw CancellationError()
    }
}
