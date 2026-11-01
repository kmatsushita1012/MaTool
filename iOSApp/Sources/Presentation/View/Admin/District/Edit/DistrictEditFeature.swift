//
//  DistrictEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/06.
//

//state 共通
import ComposableArchitecture
import Shared

@Reducer
struct DistrictEditFeature {
    
    @Reducer
    enum Destination {
        case base(DistrictBaseEditFeature)
        case area(DistrictAreaEditFeature)
        case performance(PerformanceEditFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        var district: District
        var performances: [Performance]
        var imageEdit: ImageEditFeature.State
        @Shared fileprivate var appState: AppState?
        
        var isLoading: Bool = false
        var isImageEditPresented = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case cancelTapped
        case saveTapped
        case imageEditTapped
        case imageEditDismissTapped
        case imageEdit(ImageEditFeature.Action)
        case baseTapped
        case areaTapped
        case performanceAddTapped
        case performanceEditTapped(Performance)
        case postReceived(VoidAppResult)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(SaveDistrictPackUseCaseKey.self) var saveDistrictPackUseCase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<DistrictEditFeature>{
        Scope(state: \.imageEdit, action: \.imageEdit) {
            ImageEditFeature()
        }
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .cancelTapped:
                state.isImageEditPresented = false
                return .merge(.send(.imageEdit(.reset)), .dismiss)
            case .saveTapped:
                guard !state.isLoading else { return .none }
                guard let image = state.imageEdit.imagePath(applyingTo: state.district.image) else {
                    state.alert = AlertFeature.error("画像のアップロードが完了するまで保存できません。")
                    return .none
                }
                state.district.image = image
                state.isLoading = true
                return .task(Action.postReceived) { [district = state.district, performances = state.performances, appState = state.$appState] in
                    _ = try await saveDistrictPackUseCase(
                        district: district,
                        performances: performances,
                        appState: appState
                    )
                }
            case .imageEditTapped:
                guard !state.isLoading else { return .none }
                state.isImageEditPresented = true
                return .none
            case .imageEditDismissTapped:
                guard !state.imageEdit.isUploading else { return .none }
                state.isImageEditPresented = false
                return .none
            case .baseTapped:
                if let base = state.district.base{
                    state.destination = .base(DistrictBaseEditFeature.State(base: base))
                } else {
                    guard let origin = state.appState?.festivalState.festival.base else {
                        state.alert = AlertFeature.error("情報の取得に失敗しました")
                        return .none
                    }
                    state.destination = .base(DistrictBaseEditFeature.State(origin: origin))
                }
                return .none
            case .areaTapped:
                guard let origin = state.district.base ?? state.appState?.festivalState.festival.base else {
                    state.alert = AlertFeature.error("情報の取得に失敗しました")
                    return .none
                }
                state.destination = .area(
                    DistrictAreaEditFeature.State(
                        coordinates: state.district.area,
                        origin: origin
                    )
                )
                return .none
            case .performanceAddTapped:
                state.destination = .performance(PerformanceEditFeature.State(districtId: state.district.id))
                return .none
            case .performanceEditTapped(let item):
                state.destination = .performance(PerformanceEditFeature.State(item: item))
                return .none
            case .postReceived(.failure(let error)):
                state.isLoading = false
                    state.alert = AlertFeature.error("保存に失敗しました。\(error.message)")
                return .none
            case .postReceived(.success):
                state.isLoading = false
                state.isImageEditPresented = false
                return .merge(.send(.imageEdit(.reset)), .dismiss)
            case .destination(.presented(let childAction)):
                switch childAction {
                case .base(.doneTapped):
                    if let coordinate = state.destination?.base?.coordinate {
                        state.district.base = coordinate
                    }
                    state.destination = nil
                    return .none
                case .area(.doneTapped):
                    if let coordinates = state.destination?.area?.coordinates {
                        state.district.area = coordinates
                    }
                    state.destination = nil
                    return .none
                case .performance(.doneTapped):
                    if let item = state.destination?.performance?.item {
                        state.performances.upsert(item)
                    }
                    state.destination = nil
                    return .none

                case .performance(.deleteTapped):
                    if let item = state.destination?.performance?.item {
                        state.performances.removeAll(where: { $0.id == item.id })
                    }
                    state.destination = nil
                    return .none
                case .base,
                    .area,
                    .performance:
                    return .none
                }
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
}

extension DistrictEditFeature.Destination.State: Equatable {}
extension DistrictEditFeature.Destination.Action: Equatable {}

extension DistrictEditFeature.State {
    init(_ district: District, appState: Shared<AppState?>) throws {
        guard let current = appState.wrappedValue,
              let districtState = current.districtState,
              districtState.districtId == district.id,
              let currentDistrict = current.district(id: district.id) else {
            throw PresentationError.notFound
        }

        self._appState = appState
        self.district = currentDistrict
        self.performances = districtState.performances
        self.imageEdit = ImageEditFeature.State(
            targetType: .district,
            targetID: currentDistrict.id,
            image: currentDistrict.image
        )
    }
}

//            case .binding(\.image):
//                guard let item = state.selectedItem else { return .none }
//                return .task { send in
//                    do {
//                        let data = try await item.loadTransferable(type: Data.self)
//                        if let data, let uiImage = UIImage(data: data) {
//                            await send(.loadImage(.success(uiImage)))
//                        } else {
//                            await send(.loadImage(.failure(ImageError.failedToLoad)))
//                        }
//                    } catch {
//                        await send(.loadImage(.failure(error)))
//                    }
//                }
