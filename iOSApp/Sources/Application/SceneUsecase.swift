//
//  SceneUsecase.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/16.
//

import Dependencies
import Shared
import SQLiteData

enum SceneUsecaseKey: DependencyKey {
    static let liveValue: SceneUsecaseProtocol = SceneUsecase()
}

protocol SceneUsecaseProtocol: Sendable {
    func launch() async -> LaunchState
    func signIn(username: String, password: String) async throws -> SignInResult
    func confirmSignIn(password: String) async throws -> Result<UserRole, AuthError>
    func select(festivalId: Festival.ID) async throws
    func select(districtId: District.ID) async throws -> Route.ID?
}

actor SceneUsecase: SceneUsecaseProtocol {
    var userDefaults: UserDefalutsManagerProtocol
    
    @Dependency(SceneDataFetcherKey.self) var dataFetcher
    @Dependency(FestivalDataFetcherKey.self) var festivalDataFetcher
    @Dependency(AuthServiceKey.self) var authService
    
    init(userDefaults: UserDefalutsManagerProtocol = UserDefaltsManager()){
        self.userDefaults = userDefaults
    }
    
    func launch() async -> LaunchState {
        do {
            try authService.initialize()
            guard let festivalId = userDefaults.defaultFestivalId else {
                try await festivalDataFetcher.fetchAll()
                return .onboarding
            }
            let userRole = await {
                let result = await authService.getUserRole()
                switch result {
                case .success(let userRole):
                    return userRole
                case .failure:
                    return .guest
                }
            }()
            
            async let festivalTask: () = dataFetcher.launchFestival(festivalId: festivalId)
            if let districtId = userDefaults.defaultDistrictId {
                async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
                let (_, routeId) = try await(festivalTask, districtTask)
                return .district(userRole, routeId)
            } else {
                try await festivalTask
                return .festival(userRole)
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    func signIn(username: String, password: String) async throws -> SignInResult {
        let signInResult = await authService.signIn(username, password: password)
        if case .success(.headquarter(let festivalId)) = signInResult {
            try await dataFetcher.launchFestival(festivalId: festivalId)
            userDefaults.defaultDistrictId = nil
            userDefaults.defaultFestivalId = festivalId
        } else if case .success(.district(let districtId)) = signInResult {
            async let festivalTask = dataFetcher.launchFestival(districtId: districtId)
            async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
            let (festivalId, _) = try await (festivalTask, districtTask)
            userDefaults.defaultFestivalId = festivalId
            userDefaults.defaultDistrictId = districtId
        }
        return signInResult
    }
    
    func confirmSignIn(password: String) async throws -> Result<UserRole, AuthError> {
        let result = await authService.confirmSignIn(password: password)
        if case .success(.headquarter(let festivalId)) = result {
            try await dataFetcher.launchFestival(festivalId: festivalId)
            userDefaults.defaultDistrictId = nil
            userDefaults.defaultFestivalId = festivalId
        } else if case .success(.district(let districtId)) = result {
            async let festivalTask = dataFetcher.launchFestival(districtId: districtId)
            async let districtTask = dataFetcher.launchDistrict(districtId: districtId)
            let (festivalId, _) = try await (festivalTask, districtTask)
            userDefaults.defaultFestivalId = festivalId
            userDefaults.defaultDistrictId = districtId
        }
        return result
    }
    
    func select(festivalId: Shared.Festival.ID) async throws {
        try await dataFetcher.launchFestival(festivalId: festivalId)
        userDefaults.defaultFestivalId = festivalId
        userDefaults.defaultDistrictId = nil
        return
    }
    
    func select(districtId: Shared.District.ID) async throws -> Route.ID? {
        guard let district = FetchOne(District.find(districtId)).wrappedValue else {
            throw APIError.notFound(message: "指定された町が存在しません。")
        }
        let currentRouteId = try await dataFetcher.launchDistrict(districtId: districtId)
        userDefaults.defaultDistrictId = district.id
        return currentRouteId
    }
}
