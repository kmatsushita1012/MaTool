import ComposableArchitecture
import MapKit
import Shared

@Reducer
struct FestivalInfoFeature {
    enum DisplayMode: String, CaseIterable, Equatable {
        case festival = "紹介"
        case districts = "町一覧"
    }

    @Reducer
    enum Destination {
        case district(DistrictInfoFeature)
    }

    @ObservableState
    struct State: Equatable {
        let festival: Festival
        @Shared fileprivate var appState: AppState?
        var districts: [District] {
            (appState?.festivalState.districts.filter { $0.festivalId == festival.id } ?? [])
                .sorted { lhs, rhs in
                    let groupOrder = (lhs.group ?? "").localizedStandardCompare(rhs.group ?? "")
                    if groupOrder != .orderedSame {
                        return groupOrder == .orderedAscending
                    }
                    let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
                    if nameOrder != .orderedSame {
                        return nameOrder == .orderedAscending
                    }
                    return lhs.id < rhs.id
                }
        }
        var displayMode: DisplayMode = .festival
        var selectedDistrictID: District.ID?
        var region: MKCoordinateRegion?
        var isLoading = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        init(
            _ festival: Festival,
            appState: Shared<AppState?>
        ) {
            self.festival = festival
            self._appState = appState
            self.region = makeRegion(origin: festival.base, spanDelta: spanDelta)
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case districtSelected(District.ID)
        case districtReceived(AppResult<DistrictPack>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(FetchDistrictUseCaseKey.self) private var fetchDistrictUseCase
    @Dependency(\.imageCacheClient) private var imageCacheClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .districtSelected(let districtID):
                guard state.districts.contains(where: { $0.id == districtID }) else {
                    state.alert = .error("町の紹介を表示できませんでした")
                    return .none
                }
                state.selectedDistrictID = districtID
                state.isLoading = true
                let fetchDistrictUseCase = self.fetchDistrictUseCase
                let imageCacheClient = self.imageCacheClient
                return .run { send in
                    do {
                        let pack = try await fetchDistrictUseCase(districtId: districtID)
                        await imageCacheClient.preload(paths: [
                            pack.district.image.light,
                            pack.district.image.dark
                        ])
                        await send(.districtReceived(.success(pack)))
                    } catch {
                        await send(.districtReceived(.failure(error.asAppError)))
                    }
                }

            case .districtReceived(.success(let pack)):
                state.isLoading = false
                state.destination = .district(
                    DistrictInfoFeature.State(
                        pack,
                        appState: state.$appState
                    )
                )
                return .none

            case .districtReceived(.failure(let error)):
                state.isLoading = false
                state.selectedDistrictID = nil
                state.alert = .error(error.message)
                return .none

            case .destination:
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension FestivalInfoFeature.Destination.State: Equatable {}
extension FestivalInfoFeature.Destination.Action: Equatable {}
