import ComposableArchitecture
import Dependencies
import Foundation
import OSLog
import Shared

private let signInUseCaseLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MaTool", category: "SignInUseCase")

protocol SignInUseCaseProtocol: Sendable {
    func callAsFunction(
        username: String,
        password: String,
        appState: Shared<AppState?>?
    ) async throws -> SignInState
}

struct SignInUseCase: SignInUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(\.authProvider) private var authProvider
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(
        username: String,
        password: String,
        appState: Shared<AppState?>?
    ) async throws -> SignInState {
        signInUseCaseLogger.info("beginSession: started")
        let requestId = await sessionCoordinator.beginSession()
        signInUseCaseLogger.info("beginSession: completed")
        appState?.withLock { $0 = nil }
        // Clear any stale Cognito session before starting a new sign-in attempt.
        signInUseCaseLogger.info("preSignOut: started")
        do {
            try await authProvider.signOut()
            signInUseCaseLogger.info("preSignOut: completed")
        } catch {
            // A stale-session cleanup failure has historically not blocked a new sign-in.
            signInUseCaseLogger.error("preSignOut: ignored failure (\(String(reflecting: type(of: error)), privacy: .public))")
        }
        signInUseCaseLogger.info("authProvider.signIn: started")
        let signInResponse = try await authProvider.signIn(username, password)
        signInUseCaseLogger.info("authProvider.signIn: completed")
        let result: SignInState
        switch signInResponse {
        case .newPasswordRequired:
            result = .newPasswordRequired
        case .success:
            let userRole: UserRole
            do {
                signInUseCaseLogger.info("authProvider.getUserRole: started")
                userRole = try await authProvider.getUserRole()
                signInUseCaseLogger.info("authProvider.getUserRole: completed")
            } catch {
                signInUseCaseLogger.error("authProvider.getUserRole: failed; signing out (\(String(reflecting: type(of: error)), privacy: .public))")
                try? await authProvider.signOut()
                throw error
            }
            result = .signedIn(userRole)
        }
        switch result {
        case .signedIn(.headquarter(let festivalId)):
            let dataFetcher = self.dataFetcher
            signInUseCaseLogger.info("launchFestival(headquarter): started")
            let response = try await withTimeout(seconds: 30) {
                try await dataFetcher.launchFestival(festivalId: festivalId)
            }
            signInUseCaseLogger.info("launchFestival(headquarter): completed")
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
        case .signedIn(.district(let districtId)):
            let dataFetcher = self.dataFetcher
            signInUseCaseLogger.info("launchFestival/launchDistrict(district): started")
            let (festivalResponse, districtResponse) = try await withTimeout(seconds: 30) {
                async let festivalTask = dataFetcher.launchFestival(districtId: districtId)
                async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
                return try await (festivalTask, districtTask)
            }
            signInUseCaseLogger.info("launchFestival/launchDistrict(district): completed")
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
        case .signedIn(.guest):
            break
        case .newPasswordRequired:
            break
        }
        signInUseCaseLogger.info("sign-in use case: completed")
        return result
    }
}

enum SignInUseCaseKey: DependencyKey {
    static let liveValue: any SignInUseCaseProtocol = SignInUseCase()
}
