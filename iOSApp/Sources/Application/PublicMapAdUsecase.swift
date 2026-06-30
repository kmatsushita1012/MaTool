//
//  PublicMapAdUsecase.swift
//  MaTool
//
//  Created by Codex on 2026/06/30.
//

import Dependencies
import Shared

enum PublicMapAdUsecaseKey: DependencyKey {
    static let liveValue: any PublicMapAdUsecaseProtocol = PublicMapAdUsecase()
}

extension DependencyValues {
    var publicMapAdUsecase: any PublicMapAdUsecaseProtocol {
        get { self[PublicMapAdUsecaseKey.self] }
        set { self[PublicMapAdUsecaseKey.self] = newValue }
    }
}

protocol PublicMapAdUsecaseProtocol: Sendable {
    func prepareSession() async
    func handleDistrictSelection(userRole: UserRole, districtId: District.ID, periodId: Period.ID?) async throws -> Route.ID?
    func handlePeriodSelection(userRole: UserRole, districtId: District.ID) async
}

struct PublicMapAdCounter: Equatable, Sendable {
    var eligibleEventCount: Int = 0
}

struct PublicMapAdDecision: Equatable, Sendable {
    let counter: PublicMapAdCounter
    let shouldShowInterstitial: Bool
}

enum PublicMapAdPolicy {
    static func evaluate(
        userRole: UserRole,
        targetDistrictId: District.ID,
        favoriteDistrictId: District.ID?,
        counter: PublicMapAdCounter
    ) -> PublicMapAdDecision {
        guard case .headquarter = userRole else {
            let excludedDistrictIds = excludedDistrictIds(userRole: userRole, favoriteDistrictId: favoriteDistrictId)
            guard !excludedDistrictIds.contains(targetDistrictId) else {
                return .init(counter: counter, shouldShowInterstitial: false)
            }

            let nextCount = counter.eligibleEventCount + 1
            let requiresGrace = excludedDistrictIds.isEmpty
            let isWithinGrace = requiresGrace && nextCount <= 5
            let shouldShow = !isWithinGrace && nextCount.isMultiple(of: 3)
            return .init(
                counter: .init(eligibleEventCount: nextCount),
                shouldShowInterstitial: shouldShow
            )
        }

        return .init(counter: counter, shouldShowInterstitial: false)
    }

    private static func excludedDistrictIds(
        userRole: UserRole,
        favoriteDistrictId: District.ID?
    ) -> Set<District.ID> {
        var ids = Set<District.ID>()
        if let favoriteDistrictId {
            ids.insert(favoriteDistrictId)
        }
        if case .district(let districtId) = userRole {
            ids.insert(districtId)
        }
        return ids
    }
}

actor PublicMapAdUsecase: PublicMapAdUsecaseProtocol {
    private var counter = PublicMapAdCounter()

    @Dependency(SceneDataFetcherKey.self) var sceneDataFetcher
    @Dependency(UserDefaltsManagerKey.self) var userDefaults
    @Dependency(\.adManager) var adManager

    func prepareSession() async {
        counter = .init()
        await adManager.configureIfNeeded()
        await adManager.preloadInterstitial(for: .publicMapInterstitial)
    }

    func handleDistrictSelection(
        userRole: UserRole,
        districtId: District.ID,
        periodId: Period.ID?
    ) async throws -> Route.ID? {
        let routeId = try await sceneDataFetcher.launchDistrict(
            districtId: districtId,
            periodId: periodId,
            clearsExistingData: false
        )
        await evaluateAndMaybePresent(userRole: userRole, districtId: districtId)
        return routeId
    }

    func handlePeriodSelection(userRole: UserRole, districtId: District.ID) async {
        await evaluateAndMaybePresent(userRole: userRole, districtId: districtId)
    }

    private func evaluateAndMaybePresent(userRole: UserRole, districtId: District.ID) async {
        let decision = PublicMapAdPolicy.evaluate(
            userRole: userRole,
            targetDistrictId: districtId,
            favoriteDistrictId: userDefaults.defaultDistrictId,
            counter: counter
        )
        counter = decision.counter

        if decision.shouldShowInterstitial {
            await adManager.presentInterstitial(for: .publicMapInterstitial)
        } else {
            await adManager.preloadInterstitial(for: .publicMapInterstitial)
        }
    }
}
