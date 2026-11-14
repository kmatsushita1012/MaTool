import ComposableArchitecture
import Dependencies
import Shared

@Reducer
struct StoreEditFeature {
    @Reducer
    enum Destination {
        case coordinate(MapCoordinatePickerFeature)
    }

    @ObservableState
    struct State: Equatable {
        var store: AdvertiserStore?
        var festivals: [Festival]
        var selectedFestivalId: Festival.ID?
        var name: String
        var address: String
        var businessHours: String
        var description: String
        var coordinate: Coordinate?
        var isLoading = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        var isNew: Bool { store == nil }
        var festival: Festival? { festivals.first { $0.id == selectedFestivalId } }

        init(store: AdvertiserStore? = nil, festivals: [Festival]) {
            self.store = store
            self.festivals = festivals
            self.selectedFestivalId = store?.festivalId ?? festivals.first?.id
            self.coordinate = store?.coordinate
            self.name = store?.name ?? ""
            self.address = store?.address ?? ""
            self.businessHours = store?.businessHours ?? ""
            self.description = store?.description ?? ""
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case saveReceived(AppResult<StoreSaveResult>)
        case coordinateTapped
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(\.advertiserStoreUsecase) private var storeUsecase

    private enum TaskID { case save }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .saveTapped:
                guard !state.isLoading else { return .none }
                let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let address = state.address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    state.alert = .error("店名を入力してください。")
                    return .none
                }

                state.isLoading = true
                let festivalId = state.selectedFestivalId
                let coordinate = state.coordinate
                let businessHours = state.businessHours
                let description = trimmedOptional(state.description)
                if let current = state.store {
                    var updated = current
                    updated.name = name
                    updated.address = address.isEmpty ? nil : address
                    updated.coordinate = coordinate
                    updated.businessHours = businessHours.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.description = description
                    let updatedStore = updated
                    return .task(Action.saveReceived) {
                        .updated(try await storeUsecase.save(updatedStore))
                    }
                    .cancellable(id: TaskID.save, cancelInFlight: true)
                }
                guard let festivalId else {
                    state.isLoading = false
                    state.alert = .error("祭典を選択してください。")
                    return .none
                }
                return .task(Action.saveReceived) {
                    .created(try await storeUsecase.create(
                        festivalId: festivalId,
                        name: name,
                        address: address.isEmpty ? nil : address,
                        coordinate: coordinate,
                        businessHours: businessHours.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description
                    ))
                }
                .cancellable(id: TaskID.save, cancelInFlight: true)

            case .saveReceived(.success(let result)):
                state.isLoading = false
                let savedStore: AdvertiserStore
                switch result {
                case .created(let store), .updated(let store):
                    savedStore = store
                }
                state.store = savedStore
                state.selectedFestivalId = savedStore.festivalId
                state.name = savedStore.name
                state.address = savedStore.address ?? ""
                state.businessHours = savedStore.businessHours
                state.description = savedStore.description ?? ""
                state.coordinate = savedStore.coordinate
                return .none

            case .saveReceived(.failure(let error)):
                state.isLoading = false
                state.alert = .error("保存に失敗しました。\n\(error.message)")
                return .none

            case .coordinateTapped:
                state.destination = .coordinate(
                    MapCoordinatePickerFeature.State(
                        coordinate: state.coordinate,
                        regionOrigin: state.coordinate ?? state.festival?.base ?? Coordinate(latitude: 0, longitude: 0),
                        title: "店舗位置"
                    )
                )
                return .none

            case .destination(.presented(.coordinate(.doneTapped))):
                state.coordinate = state.destination?.coordinate?.coordinate
                state.destination = nil
                return .none

            case .destination:
                return .none

            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none

            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
}

enum StoreSaveResult: Equatable {
    case created(AdvertiserStore)
    case updated(AdvertiserStore)
}

extension StoreEditFeature.Destination.State: Equatable {}
extension StoreEditFeature.Destination.Action: Equatable {}

private func trimmedOptional(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
