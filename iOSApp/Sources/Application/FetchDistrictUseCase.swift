import ComposableArchitecture
import Dependencies
import Shared

protocol FetchDistrictUseCaseProtocol: Sendable {
    func callAsFunction(districtId: District.ID) async throws -> DistrictPack
}

struct FetchDistrictUseCase: FetchDistrictUseCaseProtocol {
    @Dependency(DistrictDataFetcherKey.self) private var dataFetcher

    func callAsFunction(districtId: District.ID) async throws -> DistrictPack {
        try await dataFetcher.fetch(districtID: districtId)
    }

}

enum FetchDistrictUseCaseKey: DependencyKey {
    static let liveValue: any FetchDistrictUseCaseProtocol = FetchDistrictUseCase()
}
