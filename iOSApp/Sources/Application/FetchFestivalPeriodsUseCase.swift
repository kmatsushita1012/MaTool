import ComposableArchitecture
import Dependencies
import Shared

protocol FetchFestivalPeriodsUseCaseProtocol: Sendable {
    func callAsFunction(festivalId: Festival.ID) async throws -> [Period]
}

struct FetchFestivalPeriodsUseCase: FetchFestivalPeriodsUseCaseProtocol {
    @Dependency(PeriodDataFetcherKey.self) private var dataFetcher

    func callAsFunction(festivalId: Festival.ID) async throws -> [Period] {
        try await dataFetcher.fetchAll(festivalID: festivalId, query: .all).sorted()
    }
}

enum FetchFestivalPeriodsUseCaseKey: DependencyKey {
    static let liveValue: any FetchFestivalPeriodsUseCaseProtocol = FetchFestivalPeriodsUseCase()
}
