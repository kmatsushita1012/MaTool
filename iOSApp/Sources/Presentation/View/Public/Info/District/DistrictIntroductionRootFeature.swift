import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct DistrictIntroductionRootFeature {
    @Reducer
    enum Destination {
        case festival(FestivalInfoFeature)
    }

    @ObservableState
    struct State: Equatable {
        let festival: Festival
        let locationTimestamp: Date?
        @Shared fileprivate var appState: AppState?
        var district: DistrictInfoFeature.State
        var isLoading = false
        @Presents var destination: Destination.State?

        init(
            _ pack: DistrictPack,
            festival: Festival,
            locationTimestamp: Date? = nil,
            appState: Shared<AppState?>
        ) {
            self.festival = festival
            self.locationTimestamp = locationTimestamp
            self._appState = appState
            self.district = DistrictInfoFeature.State(pack, appState: appState)
        }
    }

    @CasePathable
    enum Action: Equatable {
        case festivalTapped
        case festivalImagePreloaded
        case district(DistrictInfoFeature.Action)
        case destination(PresentationAction<Destination.Action>)
    }

    @Dependency(\.imageCacheClient) private var imageCacheClient

    var body: some ReducerOf<Self> {
        Scope(state: \.district, action: \.district) {
            DistrictInfoFeature()
        }
        Reduce { state, action in
            switch action {
            case .festivalTapped:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                let imageCacheClient = self.imageCacheClient
                return .run { [festival = state.festival] send in
                    await imageCacheClient.preload(paths: [
                        festival.image.light,
                        festival.image.dark
                    ])
                    await send(.festivalImagePreloaded)
                }
            case .festivalImagePreloaded:
                state.isLoading = false
                state.destination = .festival(FestivalInfoFeature.State(
                    state.festival,
                    appState: state.$appState
                ))
                return .none
            case .district, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension DistrictIntroductionRootFeature.Destination.State: Equatable {}
extension DistrictIntroductionRootFeature.Destination.Action: Equatable {}
