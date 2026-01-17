//
//  FestivalDashboardFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/09.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Shared

@Reducer
struct FestivalDashboardFeature {

    @Reducer
    enum Destination {
        case edit(FestivalEditFeature)
        case districtInfo(AdminDistrictList)
        case districtCreate(AdminDistrictCreate)
        case periods(PeriodListFeature)
        case changePassword(ChangePassword)
        case updateEmail(UpdateEmail)
    }

    @ObservableState
    struct State: Equatable {
        @FetchOne var festival: Festival
        @FetchAll var districts: [District]

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
        case periodTapped
        case onDistrictInfo(District)
        case onCreateDistrict
        case homeTapped
        case changePasswordTapped
        case updateEmailTapped
        case signOutTapped
        case batchExportTapped
        case districtInfoPrepared(District)
        case signOutReceived(Result<UserRole, AuthError>)
        case batchExportPrepared(Result<[URL], APIError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }

    @Dependency(\.apiRepository) var apiRepository
    @Dependency(RouteDataFetcherKey.self) var routeDataFetcher
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<FestivalDashboardFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onEdit:
                state.destination = .edit(FestivalEditFeature.State(state.festival))
                return .none
            case .periodTapped:
                state.destination = .periods(PeriodListFeature.State(festivalId: state.festival.id))
                return .none
            case .onDistrictInfo(let district):
                state.isApiLoading = true
                return .run { send in
                    let _ = await task {
                        try await routeDataFetcher.fetchAll(districtID: district.id, query: .latest)
                    }
                    await send(.districtInfoPrepared(district))
                }
            case .onCreateDistrict:
                state.destination = .districtCreate(
                    AdminDistrictCreate.State(festivalId: state.festival.id))
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
                return batchExportEffect(state)
            case .districtInfoPrepared(let district):
                state.isApiLoading = false
                state.destination = .districtInfo(AdminDistrictList.State(district))
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
            case .destination(.presented(.edit(.putReceived(.success)))):
                state.destination = nil
                return .none
            case .destination(.presented(.districtCreate(.received(.success)))):
                state.destination = nil
                state.alert = Alert.success("参加町の追加が完了しました")
                return .none
            case .destination(.presented(.changePassword(.received(.success)))):
                state.destination = nil
                state.alert = Alert.success("パスワードが変更されました")
                return .none
            case .alert:
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    func batchExportEffect(_ state: State) -> Effect<Action> {
        .run { send in
            let districtIds = state.districts.map(\.id)
            var urls: [URL] = []
            //非同期並列にするとBEでアクセス過多
            let _ = await task {
                for districtId in districtIds {
                    guard let _ =  try? await routeDataFetcher.fetchAll(districtID: districtId, query: .latest) else { continue }
                    let routes: [Route] = FetchAll(Route.where { $0.districtId == districtId })
                        .wrappedValue
                    for route in routes {
                        guard let period: Period = FetchOne(Period.find(route.periodId)).wrappedValue,
                              (try? await routeDataFetcher.fetch(routeID: route.id)) != nil,
                              let snapshotter = RouteSnapshotter(route),
                              let image = try? await snapshotter.take(),
                              let url = snapshotter.createPDF(with: image, path: "\(period.text)")
                        else { continue }
                        urls.append(url)
                    }
                }
            }
            await send(.batchExportPrepared(.success(urls)))
        }
    }
}

extension FestivalDashboardFeature.Destination.State: Equatable {}
extension FestivalDashboardFeature.Destination.Action: Equatable {}

extension FestivalDashboardFeature.State {
    init(_ festival: Festival) {
        self._festival = FetchOne(wrappedValue: festival)
        self._districts = FetchAll(District.where { $0.festivalId == festival.id })
    }
}
