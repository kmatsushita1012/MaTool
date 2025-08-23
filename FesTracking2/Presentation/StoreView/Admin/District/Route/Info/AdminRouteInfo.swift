//
//  AdminRouteInfo.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/11.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AdminRouteInfo {
    
    @Reducer
    enum Destination {
        case map(AdminRouteMap)
    }
    
    @Reducer
    enum AlertDestination{
        case notice(Alert)
        case delete(Alert)
    }
    
    @ObservableState
    struct State: Equatable{
        enum Mode:Equatable {
            case create(String,Span)
            case edit(Route)
        }
        let mode: Mode
        var route: Route
        var isLoading: Bool = false
        let milestones: [Information]
        let origin: Coordinate
        @Presents var destination: Destination.State? = nil
        @Presents var alert: AlertDestination.State? = nil
        
        init(mode: Mode, milestones: [Information], origin: Coordinate){
            self.mode = mode
            self.milestones = milestones
            self.origin = origin
            switch(mode){
            case let .create(id, span):
                self.route = .init(
                    id: UUID().uuidString,
                    districtId: id,
                    date: SimpleDate.fromDate(span.start),
                    start: SimpleTime(hour: 12, minute: 0),
                    goal: SimpleTime(hour: 12, minute: 0)
                )
            case let .edit(route):
                self.route = route
            }
        }
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case mapTapped
        case saveTapped
        case cancelTapped
        case deleteTapped
        case postReceived(Result<String, APIError>)
        case deleteReceived(Result<String, APIError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertDestination.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminRouteInfo> {
        BindingReducer()
        Reduce{ state, action in
            switch (action) {
            case .binding:
                return .none
            case .mapTapped:
                //TODO 余興情報渡し
                state.destination = .map(
                    AdminRouteMap.State(
                        route: state.route,
                        milestones: state.milestones,
                        origin: state.origin
                    )
                )
                return .none
            case .saveTapped:
                if state.route.title.isEmpty {
                    state.alert = .notice(Alert.error("タイトルは1文字以上を指定してください。"))
                    return .none
                } else if state.route.title.contains("/") {
                    state.alert = .notice(Alert.error("タイトルに\"/\"を含むことはできません"))
                    return .none
                } else if state.route.start >= state.route.goal{
                    state.alert = .notice(Alert.error("終了時刻は開始時刻より前に設定してください"))
                    return .none
                }
                state.isLoading = true
                switch state.mode {
                case .create:
                    return .run { [route = state.route] send in
                        let result = await apiRepository.postRoute(route)
                        await send(.postReceived(result))
                    }
                case .edit:
                    return .run { [route = state.route] send in
                        let result = await apiRepository.putRoute(route)
                        await send(.postReceived(result))
                    }
                }
            case .cancelTapped:
                return .run { _ in
                    await dismiss()
                }
            case .deleteTapped:
                state.alert = .delete(Alert.delete())
                return .none
            case .postReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = .notice(Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)"))
                }
                return .none
            case .deleteReceived(let result):
                state.isLoading = false
                if case let .failure(error) = result {
                    state.alert = .notice(Alert.error("情報の取得に失敗しました。 \(error.localizedDescription)"))
                }
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .map(.doneTapped):
                    if case let .map(mapState) = state.destination{
                        state.route = mapState.route
                    }
                    state.destination = nil
                    return .none
                case .map:
                    return .none
                }
            case .destination(.dismiss):
                return .none
            case .alert(.presented(let destination)):
                switch destination {
                case .notice(.okTapped):
                    state.alert = nil
                    return .none
                case .delete(.okTapped):
                    state.alert = nil
                    state.isLoading = true
                    return .run { [route = state.route] send in
                        let result = await apiRepository.deleteRoute(route.id)
                        await send(.postReceived(result))
                    }
                }
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminRouteInfo.Destination.State: Equatable {}
extension AdminRouteInfo.Destination.Action: Equatable {}

extension AdminRouteInfo.AlertDestination.State: Equatable {}
extension AdminRouteInfo.AlertDestination.Action: Equatable {}

extension AdminRouteInfo.State.Mode {
    var isCreate: Bool {
        if case .create = self {
            return true
        }
        return false
    }
}

