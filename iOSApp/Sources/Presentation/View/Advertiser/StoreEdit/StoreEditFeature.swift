import ComposableArchitecture
import Dependencies
import Foundation
import Shared

@Reducer
struct StoreEditFeature {
    @Reducer
    enum Destination {
        case coordinate(DistrictBaseEditFeature)
        case credit(StoreCreditFeature)
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
        var coordinate: Coordinate
        var ownerPaused: Bool
        var bannerImagePath: String?
        var bannerPreviewData: Data?
        var isLoading = false
        var isUploading = false
        var activeUploadId: UUID?
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        var isNew: Bool { store == nil }
        var festival: Festival? { festivals.first { $0.id == selectedFestivalId } }
        var coordinateText: String {
            String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        }

        init(store: AdvertiserStore? = nil, festivals: [Festival]) {
            self.store = store
            self.festivals = festivals
            self.selectedFestivalId = store?.festivalId ?? festivals.first?.id
            let defaultCoordinate = festivals.first?.base ?? Coordinate(latitude: 0, longitude: 0)
            self.coordinate = store?.coordinate ?? defaultCoordinate
            self.name = store?.name ?? ""
            self.address = store?.address ?? ""
            self.businessHours = store?.businessHours ?? ""
            self.description = store?.description ?? ""
            self.ownerPaused = store?.ownerPaused ?? false
            self.bannerImagePath = store?.bannerImagePath
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case saveReceived(AppResult<StoreSaveResult>)
        case coordinateTapped
        case bannerPhotoSelected(StoreBannerPhotoSelection)
        case bannerPhotoLoaded(id: UUID, data: Data)
        case bannerPhotoFailed(id: UUID, message: String)
        case bannerUploadCompleted(id: UUID, data: Data, path: String)
        case bannerUploadFailed(id: UUID, message: String)
        case bannerRemoveTapped
        case creditTapped
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(\.advertiserStoreUsecase) private var storeUsecase
    @Dependency(\.photoLibraryClient) private var photoLibraryClient
    @Dependency(UploadImageUseCaseKey.self) private var uploadImageUseCase

    private enum TaskID { case save, bannerUpload }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selectedFestivalId):
                if state.isNew, let festival = state.festival {
                    state.coordinate = festival.base
                }
                return .none

            case .binding:
                return .none

            case .saveTapped:
                guard !state.isLoading, !state.isUploading else { return .none }
                let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let address = state.address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !address.isEmpty else {
                    state.alert = .error("店名と住所を入力してください。")
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
                    updated.address = address
                    updated.coordinate = coordinate
                    updated.businessHours = businessHours.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.description = description
                    updated.bannerImagePath = state.bannerImagePath
                    updated.ownerPaused = state.ownerPaused
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
                        address: address,
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
                state.address = savedStore.address
                state.businessHours = savedStore.businessHours
                state.description = savedStore.description ?? ""
                state.coordinate = savedStore.coordinate
                state.ownerPaused = savedStore.ownerPaused
                state.bannerImagePath = savedStore.bannerImagePath
                state.bannerPreviewData = nil
                return .none

            case .saveReceived(.failure(let error)):
                state.isLoading = false
                state.alert = .error("保存に失敗しました。\n\(error.message)")
                return .none

            case .coordinateTapped:
                state.destination = .coordinate(.init(base: state.coordinate, title: "店舗位置"))
                return .none

            case .destination(.presented(.coordinate(.doneTapped))):
                if let coordinate = state.destination?.coordinate?.coordinate {
                    state.coordinate = coordinate
                }
                state.destination = nil
                return .none

            case .bannerPhotoSelected(let selection):
                guard state.store != nil, !state.isUploading else { return .none }
                state.activeUploadId = selection.id
                state.isUploading = true
                let photoLibraryClient = self.photoLibraryClient
                return .run { send in
                    do {
                        guard let data = try await photoLibraryClient.loadImageData(from: selection.item) else {
                            await send(.bannerPhotoFailed(id: selection.id, message: "画像を読み込めませんでした。"))
                            return
                        }
                        await send(.bannerPhotoLoaded(id: selection.id, data: data))
                    } catch {
                        await send(.bannerPhotoFailed(id: selection.id, message: error.localizedDescription))
                    }
                }
                .cancellable(id: TaskID.bannerUpload, cancelInFlight: true)

            case .bannerPhotoLoaded(let id, let data):
                guard state.activeUploadId == id, let store = state.store else { return .none }
                let uploadImageUseCase = self.uploadImageUseCase
                return .run { send in
                    do {
                        let jpeg = try await uploadImageUseCase.prepareJPEG(from: data)
                        let path = try await uploadImageUseCase.upload(
                            target: ImageUploadTarget(type: .store, id: store.id, variant: .banner),
                            jpegData: jpeg
                        )
                        await send(.bannerUploadCompleted(id: id, data: jpeg, path: path))
                    } catch {
                        await send(.bannerUploadFailed(id: id, message: error.localizedDescription))
                    }
                }
                .cancellable(id: TaskID.bannerUpload, cancelInFlight: true)

            case .bannerPhotoFailed(let id, let message), .bannerUploadFailed(let id, let message):
                guard state.activeUploadId == id else { return .none }
                state.activeUploadId = nil
                state.isUploading = false
                state.alert = .error("画像をアップロードできませんでした。\n\(message)")
                return .none

            case .bannerUploadCompleted(let id, let data, let path):
                guard state.activeUploadId == id else { return .none }
                state.activeUploadId = nil
                state.isUploading = false
                state.bannerImagePath = path
                state.bannerPreviewData = data
                return .none

            case .bannerRemoveTapped:
                guard !state.isLoading, !state.isUploading else { return .none }
                state.bannerImagePath = nil
                state.bannerPreviewData = nil
                return .none

            case .creditTapped:
                guard let store = state.store else { return .none }
                state.destination = .credit(StoreCreditFeature.State(store: store))
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
