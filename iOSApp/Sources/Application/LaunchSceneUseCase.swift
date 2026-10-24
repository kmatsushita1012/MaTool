import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol LaunchSceneUseCaseProtocol: Sendable {
    func callAsFunction(appState: Shared<AppState?>?) async -> (LaunchState, StatusCheckResult?)
}

struct LaunchSceneUseCase: LaunchSceneUseCaseProtocol {
    @Dependency(SceneDataFetcherKey.self) private var dataFetcher
    @Dependency(LoadAppStateUseCaseKey.self) private var loadAppStateUseCase
    @Dependency(SceneSessionCoordinatorKey.self) private var sessionCoordinator
    @Dependency(AuthServiceKey.self) private var authService
    @Dependency(AppStatusClientKey.self) private var appStatusClient
    @Dependency(UserDefaltsManagerKey.self) private var userDefaults

    func callAsFunction(appState: Shared<AppState?>?) async -> (LaunchState, StatusCheckResult?) {
        let requestId = await sessionCoordinator.beginSession()
        appState?.withLock { $0 = nil }
        async let appStatusTask = appStatusClient.checkStatus()
        do {
            try authService.initialize()
            guard let festivalId = userDefaults.defaultFestivalId else {
                return (.onboarding, await appStatusTask)
            }

            let userRole = await (try? authService.getUserRole()) ?? .guest
            if let districtId = userDefaults.defaultDistrictId {
                async let festivalTask = dataFetcher.launchFestival(festivalId: festivalId)
                async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
                let (festivalResponse, districtResponse) = try await (festivalTask, districtTask)
                guard await sessionCoordinator.isCurrent(requestId) else {
                    return (.loading, await appStatusTask)
                }
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
                return (.district(userRole, districtResponse.currentRouteId), await appStatusTask)
            }

            let response = try await dataFetcher.launchFestival(festivalId: festivalId)
            guard await sessionCoordinator.isCurrent(requestId) else {
                return (.loading, await appStatusTask)
            }
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
            return (.festival(userRole), await appStatusTask)
        } catch {
            let appError = error.asAppError
            guard await sessionCoordinator.isCurrent(requestId) else {
                return (.loading, await appStatusTask)
            }
            if shouldResetSelections(after: appError) {
                userDefaults.saveDefaultFestivalId(nil)
                userDefaults.saveDefaultDistrictId(nil)
                appState?.withLock { $0 = nil }
                return (.onboarding, await appStatusTask)
            }
            return (.error(appError.message), await appStatusTask)
        }
    }

    private func shouldResetSelections(after error: AppError) -> Bool {
        if case .be(.notFound) = error { return true }
        return false
    }
}

enum LaunchSceneUseCaseKey: DependencyKey {
    static let liveValue: any LaunchSceneUseCaseProtocol = LaunchSceneUseCase()
}
