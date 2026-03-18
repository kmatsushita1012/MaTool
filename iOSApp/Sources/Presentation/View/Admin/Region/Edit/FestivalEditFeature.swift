//
//  FestivalEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import Foundation
import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct FestivalEditFeature {
    
    @Reducer
    enum Destination {
        case base(DistrictBaseEditFeature)
        case checkpoint(CheckpointEditFeature)
        case hazard(HazardSectionFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var festival: Festival
        var base: Coordinate?
        var checkpoints: [Checkpoint]
        var hazardSections: [HazardSection]
        var isLoading: Bool = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case baseTapped
        case putReceived(VoidTaskResult)
        case onCheckpointEdit(Checkpoint)
        case onCheckpointAdd
        case hazardTapped(HazardSection)
        case hazardCreateTapped
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(FestivalDataFetcherKey.self) var festivalDataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<FestivalEditFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .saveTapped:
                let name = state.festival.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let subname = state.festival.subname.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    state.alert = AlertFeature.error("祭典名を1文字以上入力してください。")
                    return .none
                }
                guard !subname.isEmpty else {
                    state.alert = AlertFeature.error("本部名を1文字以上入力してください。")
                    return .none
                }
                guard let base = state.base else {
                    state.alert = AlertFeature.error("本部所在地を設定してください。")
                    return .none
                }
                state.festival.name = name
                state.festival.subname = subname
                state.festival.base = base
                state.isLoading = true
                return .task(Action.putReceived) { [festival = state.festival, checkpoints = state.checkpoints, hazardSections = state.hazardSections] in
                    try await festivalDataFetcher.update(festival: festival, checkPoints: checkpoints, hazardSections: hazardSections)
                    await dismiss()
                }
            case .cancelTapped:
                return .dismiss
            case .baseTapped:
                if let base = state.base {
                    state.destination = .base(DistrictBaseEditFeature.State(base: base))
                } else {
                    state.destination = .base(DistrictBaseEditFeature.State(origin: state.festival.base))
                }
                return .none
            case .putReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("保存に失敗しました。\(error.localizedDescription)")
                return .none
            case .onCheckpointEdit(let item):
                state.destination = .checkpoint(
                    CheckpointEditFeature.State(
                        title: "交差点",
                        item: item
                    )
                )
                return .none
            case .onCheckpointAdd:
                state.destination = .checkpoint(
                    CheckpointEditFeature.State(
                        title: "交差点",
                        item: .init(id: UUID().uuidString, festivalId: state.festival.id)
                    )
                )
                return .none
            case .hazardTapped(let hazard):
                let mapRegion = {
                    if hazard.coordinates.isEmpty{ makeRegion(origin: state.base ?? state.festival.base, spanDelta: spanDelta) }
                    else { makeRegion(hazard.coordinates) }
                }()
                state.destination = .hazard(.init(hazard, mapRegion: mapRegion))
                return .none
            case .hazardCreateTapped:
                state.destination = .hazard(.init(.init(id: UUID().uuidString, festivalId: state.festival.id), mapRegion: makeRegion(origin: state.base ?? state.festival.base, spanDelta: spanDelta)))
                return .none
            case .destination(.presented(.base(.doneTapped))):
                state.base = state.destination?.base?.coordinate
                state.destination = nil
                return .none
            case .destination(.presented(.checkpoint(.doneTapped))):
                guard let item = state.destination?.checkpoint?.item else { return .none }
                state.checkpoints.upsert(item)
                state.destination = nil
                return .none
            case .destination(.presented(.hazard(.doneTapped))):
                guard state.destination?.hazard?.isValid ?? false,
                    let item = state.destination?.hazard?.item else { return .none }
                state.hazardSections.upsert(item)
                state.destination = nil
                return .none
            case .destination(.presented(.hazard(.deleteTapped))):
                guard let item = state.destination?.hazard?.item else { return .none }
                state.hazardSections.removeAll(of: item)
                state.destination = nil
                return .none
            case .alert(.presented(.okTapped)):
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

extension FestivalEditFeature.Destination.State: Equatable{}
extension FestivalEditFeature.Destination.Action: Equatable{}

extension FestivalEditFeature.State{
    init(_ festival: Festival){
        self.festival = festival
        self.base = festival.base
        self._checkpoints = FetchAll(Checkpoint.where{ $0.festivalId.eq(festival.id) }).wrappedValue
        self._hazardSections = FetchAll(HazardSection.where{ $0.festivalId.eq(festival.id) }).wrappedValue
    }
}
