//
//  PublicMapFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/02.
//

import MapKit
import ComposableArchitecture
import Shared

@Reducer
struct PublicMapFeature {
    struct DistrictLaunchResult: Equatable {
        let districtId: District.ID
        let routeId: Route.ID?
    }
    
    enum Content: Hashable {
        case locations
        case route(District)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.locations, .locations):
                return true
            case let (.route(lhsDistrict), .route(rhsDistrict)):
                return lhsDistrict.id == rhsDistrict.id
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .locations:
                hasher.combine("locations")
            case .route(let district):
                hasher.combine("route")
                hasher.combine(district.id)
            }
        }
    }

    struct DistrictContentGroup: Equatable, Identifiable {
        let name: String?
        var contents: [Content]

        var id: String { name ?? "" }
    }
    
    @Reducer
    enum Destination {
        case locations(PublicLocationsFeature)
        case route(PublicRouteFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        let userRole: UserRole
        @Shared fileprivate var appState: AppState?

        var contents: [Content] {
            let selectedDistrictId = selectedContent.district?.id
            let districts = appState?.routeDistrictIds(prioritizing: selectedDistrictId)
                .compactMap { appState?.district(id: $0) } ?? []
            return [.locations] + districts.map(Content.route)
        }
        var districtContentGroups: [DistrictContentGroup] {
            var groups: [DistrictContentGroup] = []

            for content in contents {
                guard case .route(let district) = content else { continue }
                let trimmedName = district.group?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = trimmedName?.isEmpty == false ? trimmedName : nil

                if !groups.isEmpty, groups[groups.count - 1].name == name {
                    groups[groups.count - 1].contents.append(content)
                } else {
                    groups.append(DistrictContentGroup(name: name, contents: [content]))
                }
            }

            return groups
        }
        var festivalTitle: String {
            appState?.festivalState.festival.name ?? ""
        }
        var selectedContent: Content
        var selectedContentItem: Content {
            contents.first(where: { $0 == selectedContent }) ?? selectedContent
        }
        var currentPeriodId: Period.ID? {
            appState?.currentPeriod(at: .now)?.id
        }
        var selectedPeriodId: Period.ID? {
            destination?.route?.selected?.period.id ?? currentPeriodId
        }
        var isLoading: Bool = false
        @Presents var destination: Destination.State?
        @Shared var mapRegion: MKCoordinateRegion
        @Shared var toast: MapToast?

        init(
            userRole: UserRole,
            selectedContent: Content,
            appState: Shared<AppState?>,
            mapRegion: Shared<MKCoordinateRegion>,
            toast: Shared<MapToast?>
        ) {
            self.userRole = userRole
            self.selectedContent = selectedContent
            self._appState = appState
            self._mapRegion = mapRegion
            self._toast = toast
        }
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        enum Delegate: Equatable {
            case settingsOrAdminTapped
            case settingsTapped
            case emergencySignOutTapped
            case introductionTapped
        }

        case onAppear
        case binding(BindingAction<State>)
        case contentSelected(Content)
        case routePrepared(District.ID, Route.ID?)
        case districtContentEvaluated(District, Bool)
        case districtLaunchReceived(AppResult<DistrictLaunchResult>)
        case errorCaught(AppError)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(LoadDistrictStateUseCaseKey.self) var loadDistrictStateUseCase
    @Dependency(\.publicMapAdUsecase) var publicMapAdUsecase
    
    var body: some ReducerOf<PublicMapFeature> {
        Reduce{ state, action in
            switch action {
            case .onAppear:
                let permissionEffect = Effect<Action>.run { send in
                    await mapLocationProvider.requestPermission()
                    await mapLocationProvider.startTracking()
                    await publicMapAdUsecase.prepareSession()
                }
                guard case .route(let district) = state.selectedContent,
                      state.appState?.district(id: district.id) != nil,
                      state.appState?.districtState?.districtId != district.id else {
                    return permissionEffect
                }
                state.isLoading = true
                return .merge(
                    permissionEffect,
                    districtLaunchEffect(district: district, periodId: state.currentPeriodId, appState: state.$appState)
                )
            case .binding:
                return .none
            case .delegate:
                return .none
            case .contentSelected(let value):
                let selectedPeriodId = state.selectedPeriodId
                state.$toast.withLock { $0 = nil }
                state.selectedContent = value
                switch value {
                case .locations:
                    guard let festival = state.appState?.festivalState.festival else { return .none }
                    state.destination = .locations(
                        PublicLocationsFeature.State(
                            festivalId: festival.id,
                            festival: festival,
                            appState: state.$appState,
                            mapRegion: state.$mapRegion,
                            toast: state.$toast
                        )
                    )
                    return .none
                case .route(let district):
                    guard state.appState?.district(id: district.id) != nil else {
                        return .none
                    }
                    state.isLoading = true
                    return districtLaunchEffect(
                        district: district,
                        periodId: selectedPeriodId,
                        appState: state.$appState
                    )
                }
            case .districtLaunchReceived(.success(let result)):
                return .send(.routePrepared(result.districtId, result.routeId))
            case .districtLaunchReceived(.failure(let error)):
                state.isLoading = false
                state.$toast.withLock { $0 = .error(error, title: "地区情報を取得できませんでした") }
                return .none
            case .routePrepared(let districtId, let routeId):
                state.isLoading = false
                guard let district = state.appState?.district(id: districtId) else {
                    return .send(.errorCaught(.be(.notFound("地区が見つかりません。"))))
                }
                state.destination = .route(
                    PublicRouteFeature.State(
                        districtId: district.id,
                        district: district,
                        routeId: routeId,
                        appState: state.$appState,
                        mapRegion: state.$mapRegion,
                        toast: state.$toast
                    )
                )
                let hasDisplayableContent = state.destination?.route?.hasDisplayableContent ?? false
                return .send(.districtContentEvaluated(district, hasDisplayableContent))
            case .districtContentEvaluated(let district, let hasDisplayableContent):
                return .run { [userRole = state.userRole, districtId = district.id] _ in
                    await publicMapAdUsecase.handleDistrictSelectionResult(
                        userRole: userRole,
                        districtId: districtId,
                        hasDisplayableContent: hasDisplayableContent
                    )
                }
            case .errorCaught(let error):
                state.$toast.withLock { $0 = .error(error, title: "地図を表示できませんでした") }
                return .none
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    func districtLaunchEffect(
        district: District,
        periodId: Period.ID?,
        appState: Shared<AppState?>
    ) -> Effect<Action> {
        .task(Action.districtLaunchReceived) {
            let response = try await loadDistrictStateUseCase(
                districtId: district.id,
                periodId: periodId,
                appState: appState
            )
            return DistrictLaunchResult(districtId: district.id, routeId: response.currentRouteId)
        }
    }
}

extension PublicMapFeature.Destination.State: Equatable {}
extension PublicMapFeature.Destination.Action: Equatable {}

extension PublicMapFeature.Content: Identifiable {
    var id:String {
        switch self {
        case .locations:
            return "locations"
        case .route(let district):
            return district.id
        }
    }

    var name: String {
        switch self {
        case .locations:
            return "現在地一覧"
        case .route(let district):
            return district.name
        }
    }

    var subname: String? {
        guard case .route(let district) = self else { return nil }
        return district.subname
    }

    var district: District? {
        guard case .route(let district) = self else { return nil }
        return district
    }
}

extension PublicMapFeature.State {
    init(
        festival: Festival,
        userRole: UserRole,
        appState: Shared<AppState?>
    ){
        self.init(
            userRole: userRole,
            selectedContent: .locations,
            appState: appState,
            mapRegion: Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta)),
            toast: Shared(value: nil)
        )
        self.destination = .locations(
            PublicLocationsFeature.State(
                festivalId: festival.id,
                festival: festival,
                appState: appState,
                mapRegion: $mapRegion,
                toast: $toast
            )
        )
    }

    init(festival: Festival, district: District, routeId: Route.ID?, userRole: UserRole, appState: Shared<AppState?>) {
        self.init(
            userRole: userRole,
            selectedContent: .route(district),
            appState: appState,
            mapRegion: Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta)),
            toast: Shared(value: nil)
        )
        if appState.wrappedValue?.districtState?.districtId == district.id {
            self.destination = .route(
                PublicRouteFeature.State(
                    districtId: district.id,
                    district: district,
                    routeId: routeId,
                    appState: appState,
                    mapRegion: $mapRegion,
                    toast: $toast
                )
            )
        }
    }
}
