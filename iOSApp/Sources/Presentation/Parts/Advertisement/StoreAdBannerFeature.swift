import ComposableArchitecture
import Foundation
import os
import Shared

private let storeAdBannerLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "MaTool",
    category: "StoreAdBannerFeature"
)

@Reducer
struct StoreAdBannerFeature {
    @ObservableState
    struct State: Equatable {
        let festivalId: Festival.ID
        var candidate: AdCandidate?
        var isLoading = false
        var isDismissEnabled = false
        var hasLoaded = false
        var isImageLoaded = false
        var isImageVisible = false
        var hasStartedDisplayingImage = false

        init(festivalId: Festival.ID) {
            self.festivalId = festivalId
        }
    }

    @CasePathable
    enum Action: Equatable {
        case load
        case loadReceived(AppResult<AdCandidate?>)
        case imageLoaded(String)
        case imageAppeared(String)
        case imageFailed(String)
        case dismissTapped(String)
        case dismissButtonEnabled(String)
    }

    @Dependency(\.storeAdBannerUsecase) private var storeAdBannerUsecase
    @Dependency(\.continuousClock) private var clock

    private enum TaskID { case load, dismissButtonTimer }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .load:
                state.candidate = nil
                state.isLoading = true
                state.isDismissEnabled = false
                state.hasLoaded = false
                state.isImageLoaded = false
                state.isImageVisible = false
                state.hasStartedDisplayingImage = false
                let festivalId = state.festivalId
                return .merge(
                    .cancel(id: TaskID.dismissButtonTimer),
                    .task(Action.loadReceived) {
                        try await storeAdBannerUsecase.nextBanner(festivalId: festivalId)
                    }
                    .cancellable(id: TaskID.load, cancelInFlight: true)
                )

            case .loadReceived(.success(let candidate)):
                state.isLoading = false
                state.hasLoaded = true
                guard let candidate else {
                    state.candidate = nil
                    let festivalId = state.festivalId
                    storeAdBannerLogger.info("No eligible banner candidate was returned for festivalId=\(festivalId, privacy: .public)")
                    return .none
                }
                guard let url = URL(string: candidate.imagePath),
                      let scheme = url.scheme?.lowercased(),
                      ["http", "https"].contains(scheme),
                      url.host != nil else {
                    state.candidate = nil
                    return .none
                }
                state.candidate = candidate
                storeAdBannerLogger.info(
                    "Banner candidate loaded storeId=\(candidate.storeId, privacy: .public) impressionId=\(candidate.impressionId, privacy: .public)"
                )
                return .none

            case .loadReceived(.failure):
                state.isLoading = false
                state.hasLoaded = true
                state.candidate = nil
                state.isDismissEnabled = false
                storeAdBannerLogger.error("Banner candidate or image preload failed")
                return .none

            case .imageLoaded(let impressionId):
                guard let candidate = state.candidate,
                      candidate.impressionId == impressionId else { return .none }
                state.isImageLoaded = true
                return displayEffectsIfReady(candidate: candidate, state: &state)

            case .imageAppeared(let impressionId):
                guard let candidate = state.candidate,
                      candidate.impressionId == impressionId else { return .none }
                state.isImageVisible = true
                return displayEffectsIfReady(candidate: candidate, state: &state)

            case .imageFailed(let impressionId):
                guard state.candidate?.impressionId == impressionId else { return .none }
                storeAdBannerLogger.error("Banner image failed to load impressionId=\(impressionId, privacy: .public)")
                state.candidate = nil
                state.isDismissEnabled = false
                state.isImageLoaded = false
                state.isImageVisible = false
                state.hasStartedDisplayingImage = false
                return .cancel(id: TaskID.dismissButtonTimer)

            case .dismissTapped(let impressionId):
                guard state.candidate?.impressionId == impressionId,
                      state.isDismissEnabled else { return .none }
                state.candidate = nil
                state.isDismissEnabled = false
                state.isImageLoaded = false
                state.isImageVisible = false
                state.hasStartedDisplayingImage = false
                return .cancel(id: TaskID.dismissButtonTimer)

            case .dismissButtonEnabled(let impressionId):
                guard state.candidate?.impressionId == impressionId,
                      state.isImageLoaded,
                      state.isImageVisible else { return .none }
                state.isDismissEnabled = true
                return .none
            }
        }
    }

    private func displayEffectsIfReady(
        candidate: AdCandidate,
        state: inout State
    ) -> Effect<Action> {
        guard state.isImageLoaded,
              state.isImageVisible,
              !state.hasStartedDisplayingImage else { return .none }

        state.hasStartedDisplayingImage = true
        let impressionId = candidate.impressionId
        let storeAdBannerUsecase = self.storeAdBannerUsecase
        let clock = self.clock
        return .merge(
            .run { _ in
                await storeAdBannerUsecase.reportImpression(candidate)
            },
            .run { send in
                try await clock.sleep(for: .seconds(5))
                await send(.dismissButtonEnabled(impressionId))
            }
            .cancellable(id: TaskID.dismissButtonTimer, cancelInFlight: true)
        )
    }
}
