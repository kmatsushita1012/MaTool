import Shared
@testable import iOSApp

actor SceneDataFetcherSpy: SceneDataFetcherProtocol {
    private let response: LaunchDistrictPack
    private var districtLaunchCalls = 0

    init(response: LaunchDistrictPack) { self.response = response }

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        throw CancellationError()
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        throw CancellationError()
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        districtLaunchCalls += 1
        return response
    }

    func districtLaunchCallCount() -> Int { districtLaunchCalls }
}

actor SignInSceneDataFetcherSpy: SceneDataFetcherProtocol {
    private let festivalPack: LaunchFestivalPack
    private let districtPack: LaunchDistrictPack
    private var requests: [String] = []

    init(festivalPack: LaunchFestivalPack, districtPack: LaunchDistrictPack) {
        self.festivalPack = festivalPack
        self.districtPack = districtPack
    }

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        requests.append("festival")
        return festivalPack
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        requests.append("festival")
        return festivalPack
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        requests.append("district")
        return districtPack
    }

    func requestedResources() -> [String] { requests }
}

actor SignInSignOutSpy {
    private var calls = 0

    func record() { calls += 1 }
    func count() -> Int { calls }
}
