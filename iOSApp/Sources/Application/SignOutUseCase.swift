import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol SignOutUseCaseProtocol: Sendable {
    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState
}

struct SignOutUseCase: SignOutUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(\.authProvider) private var authProvider
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(appState: Shared<AppState?>) async throws -> LaunchState {
        try await authProvider.signOut()

        let requestId = await sessionCoordinator.beginSession()
        appState.withLock { $0 = nil }

        guard let festivalId = userDefaults.defaultFestivalId else {
            return .onboarding
        }

        do {
            if let districtId = userDefaults.defaultDistrictId {
                async let festivalTask = dataFetcher.launchFestival(festivalId: festivalId)
                async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
                let (festivalPack, districtPack) = try await (festivalTask, districtTask)

                guard await sessionCoordinator.isCurrent(requestId) else {
                    return .loading
                }

                appState.withLock {
                    $0 = AppState(
                        festivalPack: festivalPack,
                        districtPack: districtPack,
                        districtId: districtId,
                        sessionId: requestId
                    )
                }
                return .district(.guest, districtPack.currentRouteId)
            }

            let festivalPack = try await dataFetcher.launchFestival(festivalId: festivalId)
            guard await sessionCoordinator.isCurrent(requestId) else {
                return .loading
            }

            appState.withLock {
                $0 = AppState(
                    festivalPack: festivalPack,
                    sessionId: requestId
                )
            }
            return .festival(.guest)
        } catch {
            guard await sessionCoordinator.isCurrent(requestId) else {
                return .loading
            }

            let appError = error.asAppError
            if case .be(.notFound) = appError {
                userDefaults.saveDefaultFestivalId(nil)
                userDefaults.saveDefaultDistrictId(nil)
                appState.withLock { $0 = nil }
                return .onboarding
            }
            return .error(appError.message)
        }
    }
}

enum SignOutUseCaseKey: DependencyKey {
    static let liveValue: any SignOutUseCaseProtocol = SignOutUseCase()
}
