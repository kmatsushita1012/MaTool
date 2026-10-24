import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol ConfirmSignInUseCaseProtocol: Sendable {
    func callAsFunction(password: String, appState: Shared<AppState?>?) async throws -> UserRole
}

struct ConfirmSignInUseCase: ConfirmSignInUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(AuthServiceKey.self) private var authService
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(password: String, appState: Shared<AppState?>?) async throws -> UserRole {
        let requestId = await sessionCoordinator.beginSession()
        appState?.withLock { $0 = nil }
        let role = try await authService.confirmSignIn(password: password)
        switch role {
        case .headquarter(let festivalId):
            let response = try await dataFetcher.launchFestival(festivalId: festivalId)
            guard await sessionCoordinator.isCurrent(requestId) else { throw CancellationError() }
            if let appState {
                appState.withLock {
                    $0 = AppState(
                        festivalPack: response,
                        year: Calendar.current.component(.year, from: .now),
                        sessionId: requestId
                    )
                }
            }
            userDefaults.saveDefaultDistrictId(nil)
            userDefaults.saveDefaultFestivalId(festivalId)
        case .district(let districtId):
            async let festivalTask = dataFetcher.launchFestival(districtId: districtId)
            async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
            let (festivalResponse, districtResponse) = try await (festivalTask, districtTask)
            guard await sessionCoordinator.isCurrent(requestId) else { throw CancellationError() }
            if let appState {
                appState.withLock {
                    $0 = AppState(
                        festivalPack: festivalResponse,
                        districtPack: districtResponse,
                        districtId: districtId,
                        year: Calendar.current.component(.year, from: .now),
                        sessionId: requestId
                    )
                }
            }
            userDefaults.saveDefaultFestivalId(festivalResponse.festival.id)
            userDefaults.saveDefaultDistrictId(districtId)
        case .guest:
            break
        }
        return role
    }
}

enum ConfirmSignInUseCaseKey: DependencyKey {
    static let liveValue: any ConfirmSignInUseCaseProtocol = ConfirmSignInUseCase()
}
