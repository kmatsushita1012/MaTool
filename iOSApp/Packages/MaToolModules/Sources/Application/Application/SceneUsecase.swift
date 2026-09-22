import iOSShared
//
//  SceneUsecase.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/16.
//

import Dependencies
import Shared
import SQLiteData

public enum SceneUsecaseKey: DependencyKey {
    public static let liveValue: any SceneUsecaseProtocol = SceneUsecase()
}

public enum FestivalSelectionResult: Equatable, Sendable {
    case unchanged
    case changed(UserRole)
}

public protocol SceneUsecaseProtocol: Sendable {
    func launch() async -> (LaunchState, StatusCheckResult?)
    func signIn(username: String, password: String) async throws -> SignInState
    func isValidPassword(_ password: String) -> Bool
    func confirmSignIn(password: String) async throws -> UserRole
    func refreshFestivals() async throws
    func select(festivalId: Festival.ID) async throws -> FestivalSelectionResult
    func select(districtId: District.ID) async throws -> Route.ID?
    func publicTabLinkingEnabled() async -> Bool
    func setPublicTabLinking(_ enabled: Bool) async
}

actor SceneUsecase: SceneUsecaseProtocol {
    private var userDefaultsOverride: (any UserDefalutsManagerProtocol)?
    @Dependency(SceneDataFetcherKey.self) var dataFetcher
    @Dependency(FestivalDataFetcherKey.self) var festivalDataFetcher
    @Dependency(AuthServiceKey.self) var authService
    @Dependency(AppStatusClientKey.self) var appStatusClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
    @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
    @Dependency(\.values.publicTabLinkingKey) var publicTabLinkingKey

    init(userDefaults: (any UserDefalutsManagerProtocol)? = nil) {
        self.userDefaultsOverride = userDefaults
    }
    
    func launch() async -> (LaunchState, StatusCheckResult?) {
        async let appStatusTask = appStatusClient.checkStatus()
        do {
            try authService.initialize()
            guard let festivalId = defaultFestivalId else {
                try await festivalDataFetcher.fetchAll()
                return (.onboarding, await appStatusTask)
            }
            let userRole = await {
                do {
                    return try await authService.getUserRole()
                } catch {
                    return .guest
                }
            }()
            
            async let festivalTask: () = dataFetcher.launchFestival(festivalId: festivalId)
            if let districtId = defaultDistrictId {
                async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
                let (_, routeId) = try await(festivalTask, districtTask)
                return (.district(userRole, routeId), await appStatusTask)
            } else {
                try await festivalTask
                return (.festival(userRole), await appStatusTask)
            }
        } catch {
            let appError = error.asAppError
            if shouldResetSelections(after: appError) {
                do {
                    setDefaultFestivalId(nil)
                    setDefaultDistrictId(nil)
                    try await festivalDataFetcher.fetchAll()
                    return (.onboarding, await appStatusTask)
                } catch {
                    return (.error(error.asAppError.message), await appStatusTask)
                }
            }
            return (.error(appError.message), await appStatusTask)
        }
    }

    private func shouldResetSelections(after error: AppError) -> Bool {
        if case .be(.notFound) = error {
            return true
        }
        return false
    }
    
    func signIn(username: String, password: String) async throws -> SignInState {
        let signInResult = try await authService.signIn(username, password: password)
        if case .signedIn(.headquarter(let festivalId)) = signInResult {
            try await dataFetcher.launchFestival(festivalId: festivalId)
            setDefaultDistrictId(nil)
            setDefaultFestivalId(festivalId)
        } else if case .signedIn(.district(let districtId)) = signInResult {
            async let festivalTask = dataFetcher.launchFestival(districtId: districtId)
            async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
            let (festivalId, _) = try await (festivalTask, districtTask)
            setDefaultFestivalId(festivalId)
            setDefaultDistrictId(districtId)
        }
        return signInResult
    }

    nonisolated func isValidPassword(_ password: String) -> Bool {
        @Dependency(AuthServiceKey.self) var authService
        return authService.isValidPassword(password)
    }
    
    func confirmSignIn(password: String) async throws -> UserRole {
        let result = try await authService.confirmSignIn(password: password)
        if case .headquarter(let festivalId) = result {
            try await dataFetcher.launchFestival(festivalId: festivalId)
            setDefaultDistrictId(nil)
            setDefaultFestivalId(festivalId)
        } else if case .district(let districtId) = result {
            async let festivalTask = dataFetcher.launchFestival(districtId: districtId)
            async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
            let (festivalId, _) = try await (festivalTask, districtTask)
            setDefaultFestivalId(festivalId)
            setDefaultDistrictId(districtId)
        }
        return result
    }

    func refreshFestivals() async throws {
        try await festivalDataFetcher.fetchAll()
    }
    
    func select(festivalId: Shared.Festival.ID) async throws -> FestivalSelectionResult {
        let previousFestivalId = defaultFestivalId
        let isFestivalChanged = previousFestivalId != festivalId
        guard isFestivalChanged else {
            return .unchanged
        }
        async let signOutTask: UserRole = authService.signOut()
        async let launchFestivalTask: () = dataFetcher.launchFestival(festivalId: festivalId, clearsExistingData: false)
        _ = try await (signOutTask, launchFestivalTask)
        setDefaultFestivalId(festivalId)
        setDefaultDistrictId(nil)
        return .changed(.guest)
    }
    
    func select(districtId: Shared.District.ID) async throws -> Route.ID? {
        guard let district = FetchOne(District.find(districtId)).wrappedValue else {
            throw AppError.be(.notFound("指定された町が存在しません。"))
        }
        let currentRouteId = try await dataFetcher.launchDistrict(districtId: districtId, clearsExistingData: false)
        setDefaultDistrictId(district.id)
        return currentRouteId
    }

    func publicTabLinkingEnabled() async -> Bool {
        userDefaultsClient.contains(publicTabLinkingKey)
            ? userDefaultsClient.bool(publicTabLinkingKey)
            : true
    }

    func setPublicTabLinking(_ enabled: Bool) async {
        userDefaultsClient.setBool(enabled, publicTabLinkingKey)
    }

    private var defaultFestivalId: String? {
        if let userDefaultsOverride {
            return userDefaultsOverride.defaultFestivalId
        }
        return userDefaultsClient.string(defaultFestivalKey)
    }

    private var defaultDistrictId: String? {
        if let userDefaultsOverride {
            return userDefaultsOverride.defaultDistrictId
        }
        return userDefaultsClient.string(defaultDistrictKey)
    }

    private func setDefaultFestivalId(_ value: String?) {
        if var userDefaultsOverride {
            userDefaultsOverride.defaultFestivalId = value
            self.userDefaultsOverride = userDefaultsOverride
        } else {
            userDefaultsClient.setString(value, defaultFestivalKey)
        }
    }

    private func setDefaultDistrictId(_ value: String?) {
        if var userDefaultsOverride {
            userDefaultsOverride.defaultDistrictId = value
            self.userDefaultsOverride = userDefaultsOverride
        } else {
            userDefaultsClient.setString(value, defaultDistrictKey)
        }
    }
}
