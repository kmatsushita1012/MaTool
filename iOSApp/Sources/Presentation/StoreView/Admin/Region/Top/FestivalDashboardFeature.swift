//
//  FestivalDashboardFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct FestivalDashboardFeature {
    
    @Reducer
    enum Destination {
        case edit(FestivalEditFeature)
        case districtInfo(AdminDistrictList)
        case districtCreate(AdminDistrictCreate)
        case programs(ProgramListFeature)
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
        case programTapped
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
        case programsPrepared(Result<[Program], APIError>)
        case signOutReceived(Result<UserRole,AuthError>)
        case batchExportPrepared(Result<[URL], APIError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<FestivalDashboardFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onEdit:
                state.destination = .edit(FestivalEditFeature.State(item: state.festival))
                return .none
            case .programTapped:
                state.isApiLoading = true
                return getProgramsEffect(state)
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
            case .programsPrepared(.success(let programs)):
                state.isApiLoading = false
                state.destination = .programs(.init(festivalId: state.festival.id, programs: programs))
                return .none
            case .districtsReceived(.failure(let error)),
                    .districtInfoPrepared(_, .failure(let error)),
                    .programsPrepared(.failure(let error)):
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
                    .updateEmail,
                    .programs(_):
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
    
    func getProgramsEffect(_ state: State) -> Effect<Action> {
        .run { [state] send in
            let result = await apiRepository.getPrograms(state.festival.id)
            await send(.programsPrepared(result))
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

extension FestivalDashboardFeature.Destination.State: Equatable {}
extension FestivalDashboardFeature.Destination.Action: Equatable {}

