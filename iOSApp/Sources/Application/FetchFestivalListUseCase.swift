import ComposableArchitecture
import Dependencies
import Shared

protocol FetchFestivalListUseCaseProtocol: Sendable {
    func callAsFunction() async throws -> [Festival]
}

struct FetchFestivalListUseCase: FetchFestivalListUseCaseProtocol {
    @Dependency(FestivalDataFetcherKey.self) private var dataFetcher

    func callAsFunction() async throws -> [Festival] {
        try await dataFetcher.fetchAll()
    }
}

enum FetchFestivalListUseCaseKey: DependencyKey {
    static let liveValue: any FetchFestivalListUseCaseProtocol = FetchFestivalListUseCase()
}
