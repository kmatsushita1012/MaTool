//
//  AdminRegionFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture

@Reducer
struct AdminRegionFeature {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    @Dependency(\.accessToken) var accessToken
    
    @Reducer
    enum Destination {
        case edit(AdminRegionEditFeature)
        case districtInfo(AdminRegionDistrictInfoFeature)
        case districtCreate(AdminRegionCreateDistrictFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        let region: Region
        let districts: [PublicDistrict]
        @Presents var destination: Destination.State?
        @Presents var alert: OkAlert.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case onEdit
        case onDistrictInfo(PublicDistrict)
        case onCreateDistrict
        case homeTapped
        case signOutTapped
        case districtInfoPrepared(PublicDistrict, Result<[RouteSummary],ApiError>)
        case signOutReceived(Result<Bool,AWSCognito.Error>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    var body: some ReducerOf<AdminRegionFeature> {
        Reduce { state, action in
            switch action {
            case .onEdit:
                state.destination = .edit(AdminRegionEditFeature.State(item: state.region))
                return .none
            case .onDistrictInfo(let district):
                return .run { send in
                    let result = await apiClient.getRoutes(district.id, accessToken.value)
                    await send(.districtInfoPrepared(district, result))
                }
            case .onCreateDistrict:
                state.destination = .districtCreate(AdminRegionCreateDistrictFeature.State(region: state.region))
                return .none
            case .homeTapped:
                return .none
            case .signOutTapped:
                return .run { send in
                    let result = await awsCognitoClient.signOut()
                    await send(.signOutReceived(result))
                }
            case .districtInfoPrepared(let district, .success(var routes)):
                routes.sort()
                state.destination = .districtInfo(AdminRegionDistrictInfoFeature.State(district: district, routes: routes))
                return .none
            case .districtInfoPrepared(_, .failure(_)):
                return .none
            case .signOutReceived(_):
                return .none
            case .destination(.presented(let childAction)):
                switch childAction{
                case .edit(.cancelTapped),
                    .districtInfo(.dismissTapped),
                    .districtCreate(.cancelTapped),
                    .edit(.received(.success(_))):
                    state.destination = nil
                    return .none
                case .edit,
                    .districtInfo,
                    .districtCreate:
                    return .none
                }
            case .destination(.dismiss):
                state.destination = nil
                return .none
            case .alert(.presented):
                state.alert = nil
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AdminRegionFeature.Destination.State: Equatable {}
extension AdminRegionFeature.Destination.Action: Equatable {}
