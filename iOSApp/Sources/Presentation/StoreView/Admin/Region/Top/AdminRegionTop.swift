//
//  AdminFestivalTop.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct AdminFestivalTop {
    
    @Reducer
    enum Destination {
        case edit(AdminFestivalEdit)
        case districtInfo(AdminDistrictList)
        case districtCreate(AdminDistrictCreate)
        case changePassword(ChangePassword)
        case updateEmail(UpdateEmail)
    }
    
    @ObservableState
    struct State: Equatable {
        var festival: Festival
        var districts: [District]
        var isApiLoading: Bool = false
        var isAuthLoading: Bool = false
        var isExportLoading: Bool = false
        var folder: ExportedFolder? = nil
        
        @Presents var destination: Destination.State? = nil
        @Presents var alert: Alert.State? = nil
        var isLoading: Bool {
            isApiLoading || isAuthLoading || isExportLoading
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onEdit
        case onDistrictInfo(District)
        case onCreateDistrict
        case homeTapped
        case changePasswordTapped
        case updateEmailTapped
        case signOutTapped
        case batchExportTapped
        case festivalReceived(Result<Festival,APIError>)
        case districtsReceived(Result<[District],APIError>)
        case districtInfoPrepared(District, Result<[RouteItem],APIError>)
        case signOutReceived(Result<UserRole,AuthError>)
        case batchExportPrepared(Result<[URL], APIError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminFestivalTop> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onEdit:
                state.destination = .edit(AdminFestivalEdit.State(item: state.festival))
                return .none
            case .onDistrictInfo(let district):
                state.isApiLoading = true
                return .run { send in
                    let result = await apiRepository.getRoutes(district.id)
                    await send(.districtInfoPrepared(district, result))
                }
            case .onCreateDistrict:
                state.destination = .districtCreate(AdminDistrictCreate.State(festival: state.festival))
                return .none
            case .homeTapped:
                return .run { _ in
                    await dismiss()
                }
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
            case .batchExportTapped:
                state.isExportLoading = true
                return batchExportEffect()
            case .festivalReceived(.success(let value)):
                state.isApiLoading = false
                state.festival = value
                return .none
            case .festivalReceived(.failure(let error)):
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
                state.destination = .districtInfo(
                    AdminDistrictList.State(
                        festival: state.festival,
                        district: district,
                        routes: routes.sorted()
                    )
                )
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
            case .batchExportPrepared(.success(let value)):
                state.isExportLoading = false
                state.folder = ExportedFolder(value)
                return .none
            case .batchExportPrepared(.failure(let error)):
                state.isExportLoading = false
                state.alert = Alert.error("出力に失敗しました　\(error.localizedDescription)")
                return .none
            case .destination(.presented(let childAction)):
                switch childAction{
                case .edit(.putReceived(.success)):
                    state.destination = nil
                    state.isApiLoading = true
                    return getFestivalEffect(state.festival.id)
                case .districtCreate(.received(.success)):
                    state.isApiLoading = true
                    state.destination = nil
                    state.alert = Alert.success("参加町の追加が完了しました")
                    return .run {[festivalId = state.festival.id] send in
                        let result  = await apiRepository.getDistricts(festivalId)
                        await send(.districtsReceived(result))
                    }
                case .changePassword(.received(.success)):
                    state.destination = nil
                    state.alert = Alert.success("パスワードが変更されました")
                    return .none
                case .edit,
                    .districtInfo,
                    .districtCreate,
                    .changePassword,
                    .updateEmail:
                    return .none
                }
            case .destination(.dismiss):
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
    
    func getFestivalEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let result = await apiRepository.getFestival(id)
            await send(.festivalReceived(result))
        }
    }
    
    func batchExportEffect() -> Effect<Action> {
        .run { send in
            
            let idsResult = await apiRepository.getRouteIds()
            guard let ids = idsResult.value else{
                await send(.batchExportPrepared(.failure(idsResult.error!)))
                return
            }
            var urls: [URL] = []
            //非同期並列にするとBEでアクセス過多
            for id in ids {
                let routeResult = await apiRepository.getRoute(id)
                guard let route = routeResult.value else { continue }
                let snapshotter = RouteSnapshotter(route)
                guard let image = try? await snapshotter.take() else { continue }
                guard let url = snapshotter.createPDF(with: image, path: "\(route.text(format: "D_y-m-d_T"))_full.pdf") else { continue }
                urls.append(url)
            }
            await send(.batchExportPrepared(.success(urls)))
        }
    }
}

extension AdminFestivalTop.Destination.State: Equatable {}
extension AdminFestivalTop.Destination.Action: Equatable {}

