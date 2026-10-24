import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol SignInUseCaseProtocol: Sendable {
    func callAsFunction(
        username: String,
        password: String,
        appState: Shared<AppState?>?
    ) async throws -> SignInState
}

struct SignInUseCase: SignInUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(LoadAppStateUseCaseKey.self) private var loadAppStateUseCase
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(AuthServiceKey.self) private var authService
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(
        username: String,
        password: String,
        appState: Shared<AppState?>?
    ) async throws -> SignInState {
        let requestId = await sessionCoordinator.beginSession()
        appState?.withLock { $0 = nil }
        let result = try await authService.signIn(username, password: password)
        switch result {
        case .signedIn(.headquarter(let festivalId)):
            let response = try await dataFetcher.launchFestival(festivalId: festivalId)
            guard await sessionCoordinator.isCurrent(requestId) else { throw CancellationError() }
            if let appState {
                _ = loadAppStateUseCase(
                    response,
                    districtPack: nil,
                    districtId: nil,
                    year: Calendar.current.component(.year, from: .now),
                    sessionId: requestId,
                    appState: appState
                )
            }
            userDefaults.saveDefaultDistrictId(nil)
            userDefaults.saveDefaultFestivalId(festivalId)
        case .signedIn(.district(let districtId)):
            async let festivalTask = dataFetcher.launchFestival(districtId: districtId)
            async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
            let (festivalResponse, districtResponse) = try await (festivalTask, districtTask)
            guard await sessionCoordinator.isCurrent(requestId) else { throw CancellationError() }
            if let appState {
                _ = loadAppStateUseCase(
                    festivalResponse,
                    districtPack: districtResponse,
                    districtId: districtId,
                    year: Calendar.current.component(.year, from: .now),
                    sessionId: requestId,
                    appState: appState
                )
            }
            userDefaults.saveDefaultFestivalId(festivalResponse.festival.id)
            userDefaults.saveDefaultDistrictId(districtId)
        case .signedIn(.guest):
            break
        case .newPasswordRequired:
            break
        }
        return result
    }
}

enum SignInUseCaseKey: DependencyKey {
    static let liveValue: any SignInUseCaseProtocol = SignInUseCase()
}
