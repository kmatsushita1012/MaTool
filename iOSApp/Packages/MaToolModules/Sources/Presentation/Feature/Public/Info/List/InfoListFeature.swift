import iOSShared
import Application
import View
//
//  InfoListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct InfoListFeature {
    enum Delegate: Equatable {
        case selectionChanged(PublicSelectionContext)
        case mapRequested(PublicSelectionContext)
        case navigationPopped
    }
    
    @Reducer
    enum Destination{
        case festival(FestivalInfoFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        @FetchAll var festivals: [Festival]
        @FetchAll var districts: [District]

        var selectedFestival: Festival?
        var selectedDistrictID: District.ID?
        var selectedRouteID: Route.ID?
        @Shared var publicSelection: PublicTabSelection
        @Presents var destination: Destination.State? = nil
        @Presents var alert: AlertFeature.State? = nil
        var isLoading: Bool = false
        var isFestivalListLoading: Bool = false
        
        init(festival: Festival) {
            self.init(
                festival: festival,
                district: nil,
                routeID: nil,
                publicSelection: Shared(
                    value: .initial(
                        linked: true,
                        context: .init(festivalID: festival.id)
                    )
                )
            )
        }

        init(festival: Festival, district: District?, routeID: Route.ID?) {
            self.init(
                festival: festival,
                district: district,
                routeID: routeID,
                publicSelection: Shared(
                    value: .initial(
                        linked: true,
                        context: .init(
                            festivalID: festival.id,
                            districtID: district?.id,
                            routeID: routeID
                        )
                    )
                )
            )
        }

        init(festival: Festival, publicSelection: Shared<PublicTabSelection>) {
            self.init(
                festival: festival,
                district: nil,
                routeID: nil,
                publicSelection: publicSelection
            )
        }

        init(
            festival: Festival,
            district: District?,
            routeID: Route.ID?,
            publicSelection: Shared<PublicTabSelection>
        ) {
            self._festivals = FetchAll()
            self._districts = FetchAll(festivalId: festival.id)
            self.selectedFestival = festival
            self.selectedDistrictID = district?.id
            self.selectedRouteID = routeID
            self._publicSelection = publicSelection
            self.destination = .festival(
                FestivalInfoFeature.State(item: festival, district: district)
            )
        }
    }
    
    @CasePathable
    enum Action: Equatable {
        case selectionRequested(PublicSelectionContext)
        case festivalSelected(Festival)
        case festivalTapped
        case districtTapped(District)
        case navigationPopRequested
        case districtReceived(AppResult<District>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
        case delegate(Delegate)
    }
    
    @Dependency(DistrictDataFetcherKey.self) var dataFetcher
    
    var body: some ReducerOf<InfoListFeature> {
        Reduce { state,action in
            switch action {
            case .selectionRequested(let context):
                updatePublicSelection(state: &state, context: context)
                guard let festivalID = context.festivalID,
                      let festival = FetchOne(Festival.find(festivalID)).wrappedValue else {
                    state.alert = AlertFeature.error("祭典情報の取得に失敗しました")
                    return .none
                }
                let district = context.districtID.flatMap {
                    FetchOne(District.find($0)).wrappedValue
                }
                state.selectedFestival = festival
                state.selectedDistrictID = district?.id
                state.selectedRouteID = context.routeID
                state.$districts = FetchAll(festivalId: festival.id)
                state.destination = .festival(
                    FestivalInfoFeature.State(item: festival, district: district)
                )
                guard let district else {
                    return .none
                }
                return selectDistrictEffect(state: &state, district: district)
            case .festivalSelected(let festival):
                state.selectedFestival = festival
                state.selectedDistrictID = nil
                state.selectedRouteID = nil
                updatePublicSelection(
                    state: &state,
                    festivalID: festival.id,
                    districtID: nil,
                    routeID: nil
                )
                state.$districts = FetchAll(festivalId: festival.id)
                state.destination = .festival(FestivalInfoFeature.State(item: festival))
                return .send(.delegate(.selectionChanged(.init(festivalID: festival.id))))
            case .festivalTapped:
                guard let festival = state.selectedFestival else {
                    return .none
                }
                state.destination = .festival(FestivalInfoFeature.State(item: festival))
                return .none
            case .districtTapped(let district):
                guard state.selectedFestival?.id == district.festivalId else {
                    return .none
                }
                updatePublicSelection(
                    state: &state,
                    festivalID: district.festivalId,
                    districtID: district.id,
                    routeID: state.selectedRouteID
                )
                return selectDistrictEffect(state: &state, district: district)
            case .navigationPopRequested:
                state.destination = nil
                return .none
            case .districtReceived(.success(let district)):
                state.selectedDistrictID = district.id
                updatePublicSelection(
                    state: &state,
                    festivalID: state.selectedFestival?.id ?? district.festivalId,
                    districtID: district.id,
                    routeID: state.selectedRouteID
                )
                state.isLoading = false
                return .send(
                    .delegate(
                        .selectionChanged(
                            .init(
                                festivalID: state.selectedFestival?.id ?? district.festivalId,
                                districtID: district.id,
                                routeID: state.selectedRouteID
                            )
                        )
                    )
                )
            case .districtReceived(.failure(let error)):
                state.alert = AlertFeature.error(error.message)
                state.isLoading = false
                return .none
            case .destination(.presented(.festival(.districtSelected(let district)))):
                guard let district else {
                    return .none
                }
                return .send(.districtTapped(district))
            case .destination(.presented(.festival(.mapTapped))):
                guard let festival = state.selectedFestival else {
                    return .none
                }
                state.destination = nil
                updatePublicSelection(
                    state: &state,
                    festivalID: festival.id,
                    districtID: nil,
                    routeID: nil
                )
                let context = PublicSelectionContext(festivalID: festival.id)
                return .send(.delegate(.mapRequested(context)))
            case .destination(.presented(.festival(.destination(let action)))):
                switch action {
                case .dismiss:
                    state.selectedDistrictID = nil
                    updatePublicSelection(
                        state: &state,
                        festivalID: state.selectedFestival?.id,
                        districtID: nil,
                        routeID: state.selectedRouteID
                    )
                    return .send(
                        .delegate(
                            .selectionChanged(
                                .init(
                                    festivalID: state.selectedFestival?.id,
                                    districtID: nil,
                                    routeID: state.selectedRouteID
                                )
                            )
                        )
                    )
                case .presented(.district(.routeIdReceived(.success(let routeId)))):
                    guard let district = state.destination?.festival?.destination?.district?.district else {
                        return .none
                    }
                    state.selectedDistrictID = district.id
                    state.selectedRouteID = routeId
                    updatePublicSelection(
                        state: &state,
                        festivalID: state.selectedFestival?.id ?? district.festivalId,
                        districtID: district.id,
                        routeID: routeId
                    )
                    state.destination = nil
                    guard let festival = state.selectedFestival else {
                        return .none
                    }
                    let context = PublicSelectionContext(
                        festivalID: festival.id,
                        districtID: district.id,
                        routeID: routeId
                    )
                    return .send(.delegate(.mapRequested(context)))
                case .presented(.district(.routeIdReceived(.failure(let error)))):
                    state.alert = AlertFeature.error(error.message)
                    return .none
                default:
                    return .none
                }
            case .destination(.dismiss):
                state.destination = nil
                return .send(.delegate(.navigationPopped))
            case .destination:
                return .none
            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    private func selectDistrictEffect(
        state: inout State,
        district: District
    ) -> Effect<Action> {
        state.isLoading = true
        return .task(Action.districtReceived) {
            try await dataFetcher.fetch(districtID: district.id)
            return district
        }
    }

    private func updatePublicSelection(
        state: inout State,
        context: PublicSelectionContext
    ) {
        updatePublicSelection(
            state: &state,
            festivalID: context.festivalID,
            districtID: context.districtID,
            routeID: context.routeID
        )
    }

    private func updatePublicSelection(
        state: inout State,
        festivalID: Festival.ID?,
        districtID: District.ID?,
        routeID: Route.ID?
    ) {
        state.$publicSelection.withLock {
            $0 = $0.updating(
                .init(
                    festivalID: festivalID,
                    districtID: districtID,
                    routeID: routeID
                ),
                from: .info
            )
        }
    }
}

extension InfoListFeature.Destination.State: Equatable {}
extension InfoListFeature.Destination.Action: Equatable {}
