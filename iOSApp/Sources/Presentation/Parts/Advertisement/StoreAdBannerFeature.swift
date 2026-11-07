import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct StoreAdBannerFeature {
    @ObservableState
    struct State: Equatable {
        let festivalId: Festival.ID
        var candidate: AdCandidate?
        var isLoading = false
        var isDismissed = true
        var reportedImpressionIds: Set<String> = []

        var isVisible: Bool { candidate != nil && !isDismissed }

        init(festivalId: Festival.ID) {
            self.festivalId = festivalId
        }
    }

    @CasePathable
    enum Action: Equatable {
        case load
        case loadReceived(AppResult<AdCandidate?>)
        case imageLoaded(String)
        case imageFailed(String)
        case dismissTapped
        case timerFinished
        case disappeared
    }

    @Dependency(\.storeAdBannerUsecase) private var storeAdBannerUsecase
    @Dependency(\.continuousClock) private var clock

    private enum TaskID { case load, timer }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .load:
                state.candidate = nil
                state.isDismissed = true
                state.isLoading = true
                let festivalId = state.festivalId
                return .task(Action.loadReceived) {
                    try await storeAdBannerUsecase.nextBanner(festivalId: festivalId)
                }
                .cancellable(id: TaskID.load, cancelInFlight: true)

            case .loadReceived(.success(let candidate)):
                state.isLoading = false
                guard let candidate else {
                    state.candidate = nil
                    state.isDismissed = true
                    return .none
                }
                guard let url = URL(string: candidate.imagePath),
                      let scheme = url.scheme?.lowercased(),
                      ["http", "https"].contains(scheme),
                      url.host != nil else {
                    state.candidate = nil
                    state.isDismissed = true
                    return .none
                }
                state.candidate = candidate
                state.isDismissed = false
                return .none

            case .loadReceived(.failure):
                state.isLoading = false
                state.candidate = nil
                state.isDismissed = true
                return .none

            case .imageLoaded(let impressionId):
                guard let candidate = state.candidate,
                      candidate.impressionId == impressionId,
                      !state.isDismissed,
                      state.reportedImpressionIds.insert(impressionId).inserted else { return .none }
                return .merge(
                    .run { _ in try? await storeAdBannerUsecase.reportImpression(candidate) },
                    .run { send in
                        try await clock.sleep(for: .seconds(5))
                        await send(.timerFinished)
                    }
                    .cancellable(id: TaskID.timer, cancelInFlight: true)
                )

            case .imageFailed(let impressionId):
                guard state.candidate?.impressionId == impressionId else { return .none }
                state.candidate = nil
                state.isDismissed = true
                return .cancel(id: TaskID.timer)

            case .dismissTapped, .timerFinished:
                state.isDismissed = true
                return .cancel(id: TaskID.timer)

            case .disappeared:
                state.candidate = nil
                state.isDismissed = true
                return .merge(.cancel(id: TaskID.load), .cancel(id: TaskID.timer))
            }
        }
    }
}
