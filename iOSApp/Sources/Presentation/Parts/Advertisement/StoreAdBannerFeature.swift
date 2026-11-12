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
        var impressionReportAttemptedIds: Set<String> = []

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
                let festivalId = state.festivalId
                return .task(Action.loadReceived) {
                    try await storeAdBannerUsecase.nextBanner(festivalId: festivalId)
                }
                .cancellable(id: TaskID.load, cancelInFlight: true)

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
                return .none

            case .imageLoaded(let impressionId):
                guard let candidate = state.candidate,
                      candidate.impressionId == impressionId else { return .none }
                guard state.impressionReportAttemptedIds.insert(impressionId).inserted else {
                    storeAdBannerLogger.debug("Duplicate image-loaded event ignored impressionId=\(impressionId, privacy: .public)")
                    return .none
                }
                storeAdBannerLogger.info(
                    "Impression report started storeId=\(candidate.storeId, privacy: .public) impressionId=\(impressionId, privacy: .public)"
                )
                return .merge(
                    .run { _ in
                        do {
                            try await storeAdBannerUsecase.reportImpression(candidate)
                            storeAdBannerLogger.info(
                                "Impression report succeeded storeId=\(candidate.storeId, privacy: .public) impressionId=\(impressionId, privacy: .public)"
                            )
                        } catch {
                            storeAdBannerLogger.error(
                                "Impression report failed storeId=\(candidate.storeId, privacy: .public) impressionId=\(impressionId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                            )
                        }
                    },
                    .run { send in
                        try await clock.sleep(for: .seconds(5))
                        await send(.dismissButtonEnabled(impressionId))
                    }
                    .cancellable(id: TaskID.dismissButtonTimer, cancelInFlight: true)
                )

            case .imageFailed(let impressionId):
                guard state.candidate?.impressionId == impressionId else { return .none }
                storeAdBannerLogger.error("Banner image failed to load impressionId=\(impressionId, privacy: .public)")
                state.candidate = nil
                state.isDismissEnabled = false
                return .none

            case .dismissTapped(let impressionId):
                guard state.candidate?.impressionId == impressionId,
                      state.isDismissEnabled else { return .none }
                state.candidate = nil
                state.isDismissEnabled = false
                return .cancel(id: TaskID.dismissButtonTimer)

            case .dismissButtonEnabled(let impressionId):
                guard state.candidate?.impressionId == impressionId else { return .none }
                state.isDismissEnabled = true
                return .none
            }
        }
    }
}
