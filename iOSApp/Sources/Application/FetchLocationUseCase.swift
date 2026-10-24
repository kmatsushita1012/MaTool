import ComposableArchitecture
import Dependencies
import Shared

protocol FetchLocationUseCaseProtocol: Sendable {
    func callAsFunction(festivalId: Festival.ID, appState: Shared<AppState?>) async throws -> [FloatLocation]
}

struct FetchLocationUseCase: FetchLocationUseCaseProtocol {
    @Dependency(LocationDataFetcherKey.self) private var dataFetcher

    func callAsFunction(festivalId: Festival.ID, appState: Shared<AppState?>) async throws -> [FloatLocation] {
        let sessionId = appState.wrappedValue?.sessionId
        let response = try await dataFetcher.fetchAll(festivalId: festivalId)
        appState.withLock { current in
            guard var updated = current,
                  updated.sessionId == sessionId,
                  updated.festivalState.festival.id == festivalId else { return }

            var latestByDistrict: [District.ID: FloatLocation] = [:]
            for location in response {
                if let existing = latestByDistrict[location.districtId],
                   existing.timestamp >= location.timestamp {
                    continue
                }
                latestByDistrict[location.districtId] = location
            }
            updated.festivalState.floatLocations = updated.festivalState.districts.compactMap {
                latestByDistrict[$0.id]
            }
            current = updated
        }
        return response
    }
}

enum FetchLocationUseCaseKey: DependencyKey {
    static let liveValue: any FetchLocationUseCaseProtocol = FetchLocationUseCase()
}
