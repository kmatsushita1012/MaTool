//
//  AdminRegionTop.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture

@Reducer
struct AdminRegionTop {
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.authProvider) var authProvider
    @Dependency(\.accessToken) var accessToken
    
    @Reducer
    enum Destination {
        case edit(AdminRegionEdit)
        case districtInfo(AdminRegionDistrictInfo)
        case districtCreate(AdminRegionDistrictCreate)
    }
    
    @ObservableState
    struct State: Equatable {
        let region: Region
        var districts: [PublicDistrict]
        var isLoading: Bool = false
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
        case districtsReceived(Result<[PublicDistrict],ApiError>)
        case districtInfoPrepared(PublicDistrict, Result<[RouteSummary],ApiError>)
        case signOutReceived(Result<Empty,AuthError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    var body: some ReducerOf<AdminRegionTop> {
        Reduce { state, action in
            switch action {
            case .onEdit:
                state.destination = .edit(AdminRegionEdit.State(item: state.region))
                return .none
            case .onDistrictInfo(let district):
                return .run { send in
                    let result = await apiClient.getRoutes(district.id, accessToken.value)
                    await send(.districtInfoPrepared(district, result))
                }
            case .onCreateDistrict:
                state.destination = .districtCreate(AdminRegionDistrictCreate.State(region: state.region))
                return .none
            case .homeTapped:
                return .none
            case .signOutTapped:
                return .run { send in
                    let result = await authProvider.signOut()
                    await send(.signOutReceived(result))
                }
            case .districtsReceived(.success(let value)):
                state.isLoading = false
                state.districts = value
                return .none
            case .districtsReceived(.failure(let error)):
                state.alert = OkAlert.error("情報の取得に失敗しました。\(error.localizedDescription)")
                return .none
            case .districtInfoPrepared(let district, .success(let routes)):
                state.destination = .districtInfo(AdminRegionDistrictInfo.State(district: district, routes: routes.sorted()))
                return .none
            case .districtInfoPrepared(_, .failure(let error)):
                state.alert = OkAlert.error("情報の取得に失敗しました。\(error.localizedDescription)")
                return .none
            case .signOutReceived(.success):
                return .none
            case .signOutReceived(.failure(let error)):
                state.alert = OkAlert.error("サインアウトに失敗しました。\(error.localizedDescription)")
                return .none
            case .destination(.presented(let childAction)):
                switch childAction{
                case .edit(.received(.success)):
                    state.destination = nil
                    return .none
                case .districtCreate(.received(.success)):
                    state.isLoading = true
                    state.destination = nil
                    state.alert = OkAlert.success("参加町の追加が完了しました。")
                    return .run {[regionId = state.region.id] send in
                        let result  = await apiClient.getDistricts(regionId)
                        await send(.districtsReceived(result))
                    }
                case .districtCreate(.received(.failure(_))):
                    state.destination = nil
                    state.alert = OkAlert.error("参加町の追加に失敗しました。")
                    return .none
                case .edit(.cancelTapped),
                    .districtInfo(.dismissTapped),
                    .districtCreate(.cancelTapped):
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

extension AdminRegionTop.Destination.State: Equatable {}
extension AdminRegionTop.Destination.Action: Equatable {}
