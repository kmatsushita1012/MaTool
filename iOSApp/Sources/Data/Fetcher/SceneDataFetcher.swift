import Dependencies
import Shared

protocol SceneDataFetcherProtocol: DataFetcher {
    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack
    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack
    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack
}

extension SceneDataFetcherProtocol {
    func launchDistrict(districtId: District.ID) async throws -> LaunchDistrictPack {
        try await launchDistrict(districtId: districtId, periodId: nil)
    }
}

enum SceneDataFetcherKey: DependencyKey {
    static let liveValue: SceneDataFetcherProtocol = SceneDataFetcher()
}

struct SceneDataFetcher: SceneDataFetcherProtocol {
    @Dependency(HTTPClientKey.self) var client

    func launchFestival(festivalId: Festival.ID) async throws -> LaunchFestivalPack {
        try await fetchFestivalPack(path: "/festivals/\(festivalId)/launch")
    }

    func launchFestival(districtId: District.ID) async throws -> LaunchFestivalPack {
        try await fetchFestivalPack(path: "/districts/\(districtId)/launch-festival")
    }

    private func fetchFestivalPack(path: String) async throws -> LaunchFestivalPack {
        try await client.get(path: path, accessToken: await getToken(), isCache: false)
    }

    func launchDistrict(districtId: District.ID, periodId: Period.ID?) async throws -> LaunchDistrictPack {
        let query = periodId.map { ["periodId": $0] } ?? [:]
        return try await client.get(
            path: "/districts/\(districtId)/launch",
            query: query,
            accessToken: await getToken(),
            isCache: false
        )
    }
}
