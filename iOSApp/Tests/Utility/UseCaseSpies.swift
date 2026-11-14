import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

actor FetchDistrictUseCaseSpy: FetchDistrictUseCaseProtocol {
    let pack: DistrictPack?
    private(set) var requestedIDs: [District.ID] = []

    init(pack: DistrictPack? = nil) { self.pack = pack }

    func callAsFunction(districtId: District.ID) async throws -> DistrictPack {
        requestedIDs.append(districtId)
        guard let pack else {
            Issue.record("Unexpected FetchDistrictUseCaseSpy call: \(districtId)")
            throw SpyInvocationError.unexpected("FetchDistrictUseCase \(districtId)")
        }
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


// Default use-case spies record unexpected work without reaching live services.
actor LaunchSceneUseCaseSpy: LaunchSceneUseCaseProtocol {
    private(set) var calls = 0

    func callAsFunction(appState: Shared<AppState?>?) async -> (LaunchState, StatusCheckResult?) {
        calls += 1
        Issue.record("Unexpected LaunchSceneUseCaseSpy call")
        return (.loading, nil)
    }
}

actor SignOutUseCaseSpy: SignOutUseCaseProtocol {
    private(set) var calls = 0

    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState {
        calls += 1
        Issue.record("Unexpected SignOutUseCaseSpy call")
        throw SpyInvocationError.unexpected("SignOutUseCase")
    }
}

actor UnconfiguredLoadDistrictStateUseCaseSpy: LoadDistrictStateUseCaseProtocol {
    private(set) var requestedDistrictIDs: [District.ID] = []

    func callAsFunction(
        districtId: District.ID,
        periodId: Period.ID?,
        appState: Shared<AppState?>
    ) async throws -> LaunchDistrictPack {
        requestedDistrictIDs.append(districtId)
        Issue.record("Unexpected LoadDistrictStateUseCaseSpy call: \(districtId)")
        throw SpyInvocationError.unexpected("LoadDistrictStateUseCase \(districtId)")
    }
}


actor ConfirmSignInUseCaseSpy: ConfirmSignInUseCaseProtocol {
    private(set) var passwords: [String] = []
    private let result: Result<UserRole, AppError>

    init(result: Result<UserRole, AppError>) {
        self.result = result
    }

    func callAsFunction(password: String, appState: Shared<AppState?>?) async throws -> UserRole {
        passwords.append(password)
        return try result.get()
    }
}


actor CreateDistrictUseCaseSpy: CreateDistrictUseCaseProtocol {
    struct Call: Equatable, Sendable {
        let name: String
        let email: String
        let festivalId: Festival.ID
    }
    private(set) var calls: [Call] = []
    let result: Result<DistrictPack, AppError>

    init(result: Result<DistrictPack, AppError>) { self.result = result }

    func callAsFunction(
        name: String, email: String, festivalId: Festival.ID,
        appState: Shared<AppState?>
    ) async throws -> DistrictPack {
        calls.append(Call(name: name, email: email, festivalId: festivalId))
        return try result.get()
    }
}

actor ReissueDistrictUseCaseSpy: ReissueDistrictUseCaseProtocol {
    struct Call: Equatable, Sendable {
        let districtId: District.ID
        let email: String
    }
    private(set) var calls: [Call] = []
    let result: Result<DistrictPack, AppError>

    init(result: Result<DistrictPack, AppError>) { self.result = result }

    func callAsFunction(
        districtId: District.ID, email: String,
        appState: Shared<AppState?>
    ) async throws -> DistrictPack {
        calls.append(Call(districtId: districtId, email: email))
        return try result.get()
    }
}

actor SelectFestivalUseCaseSpy: SelectFestivalUseCaseProtocol {
    private(set) var festivalIDs: [Festival.ID] = []
    private let error: AppError

    init(error: AppError) { self.error = error }

    func callAsFunction(
        festivalId: Festival.ID, appState: Shared<AppState?>?,
        signOutCurrentUser: Bool
    ) async throws -> FestivalSelectionResult {
        festivalIDs.append(festivalId)
        throw error
    }
}

actor SelectDistrictUseCaseSpy: SelectDistrictUseCaseProtocol {
    private(set) var districtIDs: [District.ID?] = []
    private let error: AppError

    init(error: AppError) { self.error = error }

    func callAsFunction(
        districtId: District.ID?, appState: Shared<AppState?>?
    ) async throws -> Route.ID? {
        districtIDs.append(districtId)
        throw error
    }
}


actor SignInUseCaseSpy: SignInUseCaseProtocol {
    struct Call: Equatable, Sendable {
        let username: String
        let password: String
    }
    private(set) var calls: [Call] = []
    private let result: Result<SignInState, AppError>

    init(result: Result<SignInState, AppError>) { self.result = result }

    func callAsFunction(
        username: String, password: String, appState: Shared<AppState?>?
    ) async throws -> SignInState {
        calls.append(Call(username: username, password: password))
        return try result.get()
    }
}

actor ResetPasswordUseCaseSpy: ResetPasswordUseCaseProtocol {
    private(set) var usernames: [String] = []
    private let result: Result<Void, AppError>

    init(result: Result<Void, AppError> = .success(())) { self.result = result }

    func callAsFunction(username: String) async throws {
        usernames.append(username)
        try result.get()
    }
}

actor ConfirmResetPasswordUseCaseSpy: ConfirmResetPasswordUseCaseProtocol {
    struct Call: Equatable, Sendable {
        let username: String
        let newPassword: String
        let code: String
    }
    private(set) var calls: [Call] = []
    private let result: Result<Void, AppError>

    init(result: Result<Void, AppError> = .success(())) { self.result = result }

    func callAsFunction(username: String, newPassword: String, code: String) async throws {
        calls.append(Call(username: username, newPassword: newPassword, code: code))
        try result.get()
    }
}

actor UpdateEmailUseCaseSpy: UpdateEmailUseCaseProtocol {
    private(set) var emails: [String] = []
    private let result: Result<UpdateEmailState, AppError>

    init(result: Result<UpdateEmailState, AppError>) { self.result = result }

    func callAsFunction(email: String) async throws -> UpdateEmailState {
        emails.append(email)
        return try result.get()
    }
}

actor ConfirmUpdateEmailUseCaseSpy: ConfirmUpdateEmailUseCaseProtocol {
    private(set) var codes: [String] = []
    private let result: Result<Void, AppError>

    init(result: Result<Void, AppError> = .success(())) { self.result = result }

    func callAsFunction(code: String) async throws {
        codes.append(code)
        try result.get()
    }
}

actor FetchLocationUseCaseSpy: FetchLocationUseCaseProtocol {
    private(set) var festivalIDs: [Festival.ID] = []
    private let result: Result<[FloatLocation], AppError>

    init(result: Result<[FloatLocation], AppError>) { self.result = result }

    func callAsFunction(
        festivalId: Festival.ID, appState: Shared<AppState?>
    ) async throws -> [FloatLocation] {
        festivalIDs.append(festivalId)
        return try result.get()
    }
}
