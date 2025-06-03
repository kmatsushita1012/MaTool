//
//  AdminDistrictFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import ComposableArchitecture

@Reducer
struct AdminDistrictFeature {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationSharingUseCase) var usecase
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    @Dependency(\.accessToken) var accessToken
    
    @Reducer
    enum Destination {
        case edit(AdminDistrictEditFeature)
        case route(AdminRouteInfoFeature)
        case location(AdminLocationFeature)
    }
    
    @ObservableState
    struct State:Equatable {
        var district: PublicDistrict
        var routes: [RouteSummary]
        var isDistrictLoading: Bool = false
        var isRoutesLoading: Bool = false
        var isAWSLoading: Bool = false
        @Presents var destination: Destination.State?
        @Presents var alert: OkAlert.State?
        var isLoading: Bool {
            isDistrictLoading || isRoutesLoading || isAWSLoading
        }
    }
    
    @CasePathable
    enum Action: Equatable {
        case onEdit
        case onRouteAdd
        case onRouteEdit(RouteSummary)
        case getDistrictReceived(Result<PublicDistrict,ApiError>)
        case getRoutesReceived(Result<[RouteSummary],ApiError>)
        case onLocation
        case destination(PresentationAction<Destination.Action>)
        case onSignOut
        case signOutReceived(Result<Bool,AWSCognito.Error>)
        case homeTapped
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    
    var body: some ReducerOf<AdminDistrictFeature> {
        Reduce{state,action in
            switch action {
            case .onEdit:
                state.destination = .edit(AdminDistrictEditFeature.State(item: state.district.toModel()))
                return .none
            case .onRouteAdd:
                state.destination = .route(AdminRouteInfoFeature.State(mode: .create(districtId: state.district.id), performances: state.district.performances))
                return .none
            case .onRouteEdit(let route):
                state.destination = .route(AdminRouteInfoFeature.State(mode: .edit(id: route.id), performances: state.district.performances))
                return .none
            case .getDistrictReceived(let result):
                state.isDistrictLoading = false
                switch result {
                case .success(let value):
                    state.district = value
                case .failure(let error):
                    state.alert = OkAlert.make("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .getRoutesReceived(let result):
                state.isRoutesLoading = false
                switch result {
                case .success(var value):
                    value.sort()
                    state.routes = value
                case .failure(let error):
                    state.alert = OkAlert.make("情報の取得に失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .onLocation:
                state.destination = .location(AdminLocationFeature.State(id: state.district.id, isTracking: usecase.isTracking))
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .edit(.cancelTapped),
                    .route(.cancelTapped),
                    .location(.dismissTapped):
                    state.destination = nil
                    return .none
                case .edit(.postReceived(.success(_))),
                    .route(.postReceived(.success(_))),
                    .route(.deleteReceived(.success(_))):
                    state.destination = nil
                    state.isDistrictLoading = true
                    state.isRoutesLoading = true
                    return .merge(
                        .run {[id = state.district.id] send in
                            let result = await apiClient.getDistrict(id)
                            await send(.getDistrictReceived(result))
                        },
                        .run {[id = state.district.id] send in
                            let result = await apiClient.getRoutes(id, accessToken.value)
                            await send(.getRoutesReceived(result))
                        }
                    )
                default:
                    return .none
                }
            case .onSignOut:
                state.isAWSLoading = true
                return .run { send in
                    let result = await awsCognitoClient.signOut()
                    await send(.signOutReceived(result))
                }
            case .signOutReceived(let result):
                state.isAWSLoading = false
                if case let .failure(error) = result {
                    state.alert = OkAlert.make("サインアウトに失敗しました。 \(error.localizedDescription)")
                }
                return .none
            case .destination(.dismiss):
                state.destination = nil
                return .none
            case .homeTapped:
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert(_):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminDistrictFeature.Destination.State: Equatable {}
extension AdminDistrictFeature.Destination.Action: Equatable {}
