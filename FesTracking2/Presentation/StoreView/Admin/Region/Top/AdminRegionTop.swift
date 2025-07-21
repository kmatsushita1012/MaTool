//
//  AdminRegionTop.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture

@Reducer
struct AdminRegionTop {
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    
    @Reducer
    enum Destination {
        case edit(AdminRegionEdit)
        case districtInfo(AdminRegionDistrictList)
        case districtCreate(AdminRegionDistrictCreate)
        case changePassword(ChangePassword)
        case updateEmail(UpdateEmail)
    }
    
    @ObservableState
    struct State: Equatable {
        var region: Region
        var districts: [PublicDistrict]
        var isApiLoading: Bool = false
        var isAuthLoading: Bool = false
        @Presents var destination: Destination.State? = nil
        @Presents var alert: Alert.State? = nil
        var isLoading: Bool {
            isApiLoading || isAuthLoading
        }
    }
    
    @CasePathable
    enum Action: Equatable {
        case onEdit
        case onDistrictInfo(PublicDistrict)
        case onCreateDistrict
        case homeTapped
        case changePasswordTapped
        case updateEmailTapped
        case signOutTapped
        case regionReceived(Result<Region,ApiError>)
        case districtsReceived(Result<[PublicDistrict],ApiError>)
        case districtInfoPrepared(PublicDistrict, Result<[RouteSummary],ApiError>)
        case signOutReceived(Result<UserRole,AuthError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    var body: some ReducerOf<AdminRegionTop> {
        Reduce { state, action in
            switch action {
            case .onEdit:
                state.destination = .edit(AdminRegionEdit.State(item: state.region))
                return .none
            case .onDistrictInfo(let district):
                state.isApiLoading = true
                return .run { send in
                    let result = await apiRepository.getRoutes(district.id, authService.getAccessToken())
                    await send(.districtInfoPrepared(district, result))
                }
            case .onCreateDistrict:
                state.destination = .districtCreate(AdminRegionDistrictCreate.State(region: state.region))
                return .none
            case .homeTapped:
                return .none
            case .changePasswordTapped:
                state.destination = .changePassword(ChangePassword.State())
                return .none
            case .updateEmailTapped:
                state.destination = .updateEmail(UpdateEmail.State())
                return .none
            case .signOutTapped:
                state.isAuthLoading = true
                return .run { send in
                    let result = await authService.signOut()
                    await send(.signOutReceived(result))
                }
            case .regionReceived(.success(let value)):
                state.isApiLoading = false
                state.region = value
                return .none
            case .regionReceived(.failure(let error)):
                state.isApiLoading = false
                state.alert = Alert.error("情報の取得に失敗しました。\(error.localizedDescription)")
                return .none
            case .districtsReceived(.success(let value)):
                state.isApiLoading = false
                state.districts = value
                return .none
            case .districtsReceived(.failure(let error)):
                state.isApiLoading = false
                state.alert = Alert.error("情報の取得に失敗しました。\(error.localizedDescription)")
                return .none
            case .districtInfoPrepared(let district, .success(let routes)):
                state.isApiLoading = false
                state.destination = .districtInfo(AdminRegionDistrictList.State(district: district, routes: routes.sorted()))
                return .none
            case .districtInfoPrepared(_, .failure(let error)):
                state.isApiLoading = false
                state.alert = Alert.error("情報の取得に失敗しました \(error.localizedDescription)")
                return .none
            case .signOutReceived(.success):
                state.isAuthLoading = false
                return .none
            case .signOutReceived(.failure(let error)):
                state.isAuthLoading = false
                state.alert = Alert.error("ログアウトに失敗しました　\(error.localizedDescription)")
                return .none
            case .destination(.presented(let childAction)):
                switch childAction{
                case .edit(.putReceived(.success)):
                    state.isApiLoading = true
                    state.destination = nil
                    return getRegionEffect(state.region.id)
                case .districtCreate(.received(.success)):
                    state.isApiLoading = true
                    state.destination = nil
                    state.alert = Alert.success("参加町の追加が完了しました")
                    return .run {[regionId = state.region.id] send in
                        let result  = await apiRepository.getDistricts(regionId)
                        await send(.districtsReceived(result))
                    }
                case .districtCreate(.received(.failure(_))):
                    state.destination = nil
                    state.alert = Alert.error("参加町の追加に失敗しました")
                    return .none
                case .changePassword(.received(.success)):
                    state.destination = nil
                    state.alert = Alert.success("パスワードが変更されました")
                    return .none
                    return .none
                case .edit(.cancelTapped),
                    .districtInfo(.dismissTapped),
                    .districtCreate(.cancelTapped),
                    .changePassword(.dismissTapped):
                    state.destination = nil
                    return .none
                case .edit,
                    .districtInfo,
                    .districtCreate,
                    .changePassword,
                    .updateEmail:
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
    
    func getRegionEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let result = await apiRepository.getRegion(id)
            await send(.regionReceived(result))
        }
    }
}

extension AdminRegionTop.Destination.State: Equatable {}
extension AdminRegionTop.Destination.Action: Equatable {}
