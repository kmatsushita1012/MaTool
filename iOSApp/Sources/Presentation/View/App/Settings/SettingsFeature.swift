//
//  SettingsFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct SettingsFeature {

    @Reducer
    enum Destination {
        case login(LoginFeature)
    }

    @ObservableState
    struct State: Equatable {
        @FetchAll var festivals: [Festival]
        var selectedFestival: Festival? = nil
        @FetchAll var districts: [District]
        var selectedDistrict: District? = nil
        @Shared var publicSelection: PublicTabSelection
        var isMapInfoLinked: Bool
        var isLoading: Bool = false
        var userGuide: URL = {
            @Dependency(\.values.userGuideUrl) var userGuideURLString
            return URL(string: userGuideURLString)!
        }()
        
        var contact: URL = {
            @Dependency(\.values.contactURL) var contactURLString
            return URL(string: contactURLString)!
        }()
        @Presents var alert: AlertFeature.State? = nil
        @Presents var destination: Destination.State?
        
        init() {
            @Dependency(\.userDefaultsClient) var userDefaultsClient
            @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
            @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
            @Dependency(\.values.publicTabLinkingKey) var publicTabLinkingKey
            let selectedFestival = FetchOne(
                Festival.where { $0.id.eq(userDefaultsClient.string(defaultFestivalKey)) }
            ).wrappedValue
            let selectedDistrict = FetchOne(
                District.where { $0.id.eq(userDefaultsClient.string(defaultDistrictKey)) }
            ).wrappedValue
            let isLinked = userDefaultsClient.contains(publicTabLinkingKey)
                ? userDefaultsClient.bool(publicTabLinkingKey)
                : true
            self.selectedFestival = selectedFestival
            self.selectedDistrict = selectedDistrict
            self.isMapInfoLinked = isLinked
            self._festivals = FetchAll()
            self._districts = FetchAll(District.where { $0.festivalId.eq(selectedFestival?.id) }.order(by: \.order))
            self._publicSelection = Shared(
                value: .initial(
                    linked: isLinked,
                    context: .init(
                        festivalID: selectedFestival?.id,
                        districtID: selectedDistrict?.id
                    )
                )
            )
        }

        init(publicSelection: Shared<PublicTabSelection>) {
            @Dependency(\.userDefaultsClient) var userDefaultsClient
            @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
            @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
            @Dependency(\.values.publicTabLinkingKey) var publicTabLinkingKey
            let selectedFestival = FetchOne(
                Festival.where { $0.id.eq(userDefaultsClient.string(defaultFestivalKey)) }
            ).wrappedValue
            let selectedDistrict = FetchOne(
                District.where { $0.id.eq(userDefaultsClient.string(defaultDistrictKey)) }
            ).wrappedValue
            let isLinked = userDefaultsClient.contains(publicTabLinkingKey)
                ? userDefaultsClient.bool(publicTabLinkingKey)
                : true
            self.selectedFestival = selectedFestival
            self.selectedDistrict = selectedDistrict
            self.isMapInfoLinked = isLinked
            self._festivals = FetchAll()
            self._districts = FetchAll(District.where { $0.festivalId.eq(selectedFestival?.id) }.order(by: \.order))
            self._publicSelection = publicSelection
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        enum Delegate: Equatable {
            case userRoleChanged(UserRole)
            case publicSelectionLinkChanged(Bool)
        }

        case binding(BindingAction<State>)
        case dismissTapped
        case signOutTapped
        case signOutReceived(AppResult<UserRole>)
        case festivalSelectReceived(AppResult<FestivalSelectionResult>)
        case districtSelectReceived(AppResult<Route.ID?>)
        case loginTapped
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.authService) var authService
    @Dependency(SceneUsecaseKey.self) var sceneUsecase
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
    @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
    
    var body: some ReducerOf<SettingsFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(\.selectedFestival):
                guard let festival = state.selectedFestival else { return .none }
                state.isLoading = true
                return .task(Action.festivalSelectReceived) {
                    try await sceneUsecase.select(festivalId: festival.id)
                }
            case .binding(\.selectedDistrict):
                guard let district = state.selectedDistrict else { return .none }
                state.isLoading = true
                return .task(Action.districtSelectReceived) {
                    try await sceneUsecase.select(districtId: district.id)
                }
            case .binding(\.isMapInfoLinked):
                let enabled = state.isMapInfoLinked
                let mapContext = state.publicSelection.context(for: .map)
                let infoContext = state.publicSelection.context(for: .info)
                state.$publicSelection.withLock {
                    $0 = $0.settingLinking(
                        enabled,
                        mapContext: mapContext,
                        infoContext: infoContext
                    )
                }
                return .merge(
                    .run { _ in
                        await sceneUsecase.setPublicTabLinking(enabled)
                    },
                    .send(.delegate(.publicSelectionLinkChanged(enabled)))
                )
            case .binding:
                return .none
            case .loginTapped:
                state.destination = .login(LoginFeature.State())
                return .none
            case .signOutTapped:
                return .task(Action.signOutReceived) {
                    try await authService.signOut()
                }
            case .signOutReceived(.success(let userRole)):
                state.alert = AlertFeature.success("ログアウトしました")
                return .send(.delegate(.userRoleChanged(userRole)))
            case .signOutReceived(.failure(let error)):
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
                return .none
            case .festivalSelectReceived(.success(let result)):
                if case .changed = result {
                    state.selectedDistrict = nil
                    state.$districts = FetchAll(District.where{ $0.festivalId.eq(state.selectedFestival?.id)}.order(by: \.order))
                }
                state.isLoading = false
                return .none
            case .districtSelectReceived(.success(_)):
                state.isLoading = false
                return .none
            case .festivalSelectReceived(.failure(let error)),
                .districtSelectReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("情報の取得に失敗しました \(error.message)")
                return .none
            case .destination(.presented(.login(.received(.success(.signedIn(let userRole)))))) ,
                .destination(.presented(.login(.confirmSignInCompleted(let userRole)))):
                state.destination = nil
                return .send(.delegate(.userRoleChanged(userRole)))
            case .destination:
                return .none
            case .delegate:
                return .none
            case .alert:
                state.alert = nil
                return .none
            case .dismissTapped:
                return .dismiss
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

extension SettingsFeature.Destination.State: Equatable {}
extension SettingsFeature.Destination.Action: Equatable {}
