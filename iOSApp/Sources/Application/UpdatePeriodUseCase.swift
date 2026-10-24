import ComposableArchitecture
import Dependencies
import Foundation
import Shared

protocol UpdatePeriodUseCaseProtocol: Sendable {
    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period
}

struct UpdatePeriodUseCase: UpdatePeriodUseCaseProtocol {
    @Dependency(PeriodDataFetcherKey.self) private var dataFetcher
    @Dependency(RouteDataFetcherKey.self) private var routeDataFetcher

    func callAsFunction(_ period: Period, appState: Shared<AppState?>) async throws -> Period {
        let context = appState.withLock { current -> (sessionId: UUID, districtId: District.ID, districtRequestId: UUID, year: Int)? in
            guard let current,
                  let districtState = current.districtState else { return nil }
            return (
                current.sessionId,
                districtState.districtId,
                districtState.requestId,
                current.festivalState.year
            )
        }
        let sessionId = context?.sessionId ?? appState.withLock { $0?.sessionId }
        let response = try await dataFetcher.update(period)
        applyPeriodResponse(response, sessionId: sessionId, to: appState)

        guard let context, response.date.year == context.year else { return response }
        let routes: [Route]
        do {
            routes = try await routeDataFetcher.fetchAll(
                districtID: context.districtId,
                query: .year(context.year)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The period PUT already succeeded; a refresh failure must not report the save as failed.
            return response
        }
        appState.withLock { current in
            guard var updated = current,
                  updated.sessionId == context.sessionId,
                  updated.districtState?.districtId == context.districtId,
                  updated.districtState?.requestId == context.districtRequestId else { return }
            let currentPeriodIds = Set(updated.festivalState.periods.map(\.id))
            let currentRoutes = routes.filter { currentPeriodIds.contains($0.periodId) }
            updated.districtState?.routes = currentRoutes
            updated.routeLoadRequestId = UUID()
            if let routeState = updated.routeState,
               updated.districtState?.route(id: routeState.route.id) == nil {
                updated.routeState = nil
            }
            current = updated
        }
        return response
    }
}

enum UpdatePeriodUseCaseKey: DependencyKey {
    static let liveValue: any UpdatePeriodUseCaseProtocol = UpdatePeriodUseCase()
}
