import ComposableArchitecture
import Foundation
import PhotosUI
import Shared
import SwiftUI

enum ImageEditMode: Equatable, Hashable, Sendable {
    case light
    case dark
    case banner
    case interstitial

    func uploadVariant(for targetType: ImageUploadTarget.Kind) -> ImageUploadTarget.Variant {
        switch (targetType, self) {
        case (.store, .banner), (.store, .light): .banner
        case (.store, .interstitial), (.store, .dark): .interstitial
        case (.festival, .light), (.district, .light), (.festival, .banner), (.district, .banner): .light
        case (.festival, .dark), (.district, .dark), (.festival, .interstitial), (.district, .interstitial): .dark
        }
    }

    func title(for targetType: ImageUploadTarget.Kind) -> String {
        if targetType == .store {
            return switch self {
            case .banner, .light: "バナー"
            case .interstitial, .dark: "全画面"
            }
        }
        return switch self {
        case .light, .banner: "ライト"
        case .dark, .interstitial: "ダーク"
        }
    }
}

@Reducer
struct ImageEditFeature {
    typealias Mode = ImageEditMode

    enum Draft: Equatable {
        case unchanged
        case loading
        case preparing
        case uploading(Data)
        case replaced(path: String, jpegData: Data)
        case removed
    }

    @ObservableState
    struct State: Equatable {
        let targetType: ImageUploadTarget.Kind
        let targetID: String
        let originalImage: ImagePath
        var selectedMode: Mode
        var drafts: [Mode: Draft]
        var selectedPhotoItem: PhotosPickerItem?
        var isSaving = false
        var lightDraft: Draft {
            get { drafts[.light] ?? .unchanged }
            set { drafts[.light] = newValue }
        }
        var darkDraft: Draft {
            get { drafts[.dark] ?? .unchanged }
            set { drafts[.dark] = newValue }
        }
        var activeUploadID: UUID?
        var failureMessages: [Mode: String] = [:]
        @Presents var alert: AlertFeature.State?

        init(
            targetType: ImageUploadTarget.Kind,
            targetID: String,
            image: ImagePath,
            selectedMode: Mode? = nil
        ) {
            self.targetType = targetType
            self.targetID = targetID
            self.originalImage = image
            self.selectedMode = selectedMode ?? (targetType == .store ? .banner : .light)
            self.drafts = [
                .light: .unchanged,
                .dark: .unchanged,
                .banner: .unchanged,
                .interstitial: .unchanged
            ]
        }

        var isUploading: Bool { activeUploadID != nil }

        var canSave: Bool { !isUploading && !isSaving }

        var previewData: Data? {
            switch draft(for: selectedMode) {
            case .uploading(let data), .replaced(_, let data): data
            default: nil
            }
        }

        var previewURL: String? {
            switch draft(for: selectedMode) {
            case .unchanged, .loading, .preparing:
                imagePath(for: selectedMode)
            case .uploading, .replaced, .removed:
                nil
            }
        }

        var hasImage: Bool { previewData != nil || previewURL != nil }

        func imagePath(applyingTo image: ImagePath) -> ImagePath? {
            guard canSave else { return nil }
            return ImagePath(
                light: path(
                    for: draft(for: targetType == .store ? .banner : .light),
                    originalPath: image.light
                ),
                dark: path(
                    for: draft(for: targetType == .store ? .interstitial : .dark),
                    originalPath: image.dark
                )
            )
        }

        func draft(for mode: Mode) -> Draft {
            drafts[mode] ?? .unchanged
        }

        func failureMessage(for mode: Mode) -> String? {
            failureMessages[mode]
        }

        private func imagePath(for mode: Mode) -> String? {
            switch mode {
            case .light, .banner: originalImage.light
            case .dark, .interstitial: originalImage.dark
            }
        }

        private func path(for draft: Draft, originalPath: String?) -> String? {
            switch draft {
            case .unchanged: originalPath
            case .replaced(let path, _): path
            case .removed: nil
            case .loading, .preparing, .uploading: nil
            }
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case photoSelected(id: UUID, item: PhotosPickerItem)
        case photoDataReceived(id: UUID, mode: Mode, data: Data)
        case photoDataFailed(id: UUID, mode: Mode, message: String)
        case jpegPrepared(id: UUID, mode: Mode, data: Data)
        case jpegPreparationFailed(id: UUID, mode: Mode, message: String)
        case uploadCompleted(id: UUID, mode: Mode, data: Data, path: String)
        case uploadFailed(id: UUID, mode: Mode, message: String)
        case removeTapped
        case saveTapped
        case closeTapped
        case reset
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(PhotoLibraryClientKey.self) var photoLibraryClient
    @Dependency(UploadImageUseCaseKey.self) var uploadImageUseCase

    private enum UploadTaskID: Hashable { case upload }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.selectedPhotoItem):
                guard let item = state.selectedPhotoItem else { return .none }
                state.selectedPhotoItem = nil
                return .send(.photoSelected(id: UUID(), item: item))

            case .binding(\.selectedMode):
                return .none

            case .binding:
                return .none

            case .photoSelected(let id, let item):
                guard !state.isUploading else { return .none }
                let mode = state.selectedMode
                state.failureMessages[mode] = nil
                state.activeUploadID = id
                state.drafts[mode] = .loading
                let photoLibraryClient = self.photoLibraryClient
                return .run { send in
                    do {
                        guard let data = try await photoLibraryClient.loadImageData(from: item) else {
                            await send(.photoDataFailed(
                                id: id,
                                mode: mode,
                                message: "画像を読み込めませんでした。"
                            ))
                            return
                        }
                        await send(.photoDataReceived(id: id, mode: mode, data: data))
                    } catch {
                        await send(.photoDataFailed(
                            id: id,
                            mode: mode,
                            message: error.localizedDescription
                        ))
                    }
                }
                .cancellable(id: UploadTaskID.upload, cancelInFlight: true)

            case .photoDataReceived(let id, let mode, let data):
                guard state.activeUploadID == id else { return .none }
                state.drafts[mode] = .preparing
                let uploadImageUseCase = self.uploadImageUseCase
                return .run { send in
                    do {
                        let jpeg = try await uploadImageUseCase.prepareJPEG(from: data)
                        await send(.jpegPrepared(id: id, mode: mode, data: jpeg))
                    } catch {
                        await send(.jpegPreparationFailed(
                            id: id,
                            mode: mode,
                            message: error.localizedDescription
                        ))
                    }
                }
                .cancellable(id: UploadTaskID.upload, cancelInFlight: true)

            case .photoDataFailed(let id, let mode, let message),
                 .jpegPreparationFailed(let id, let mode, let message):
                guard state.activeUploadID == id else { return .none }
                state.activeUploadID = nil
                state.drafts[mode] = .unchanged
                state.failureMessages[mode] = message
                return .none

            case .jpegPrepared(let id, let mode, let data):
                guard state.activeUploadID == id else { return .none }
                state.drafts[mode] = .uploading(data)
                return uploadEffect(id: id, mode: mode, data: data, state: state)

            case .uploadCompleted(let id, let mode, let data, let path):
                guard state.activeUploadID == id else { return .none }
                state.activeUploadID = nil
                state.drafts[mode] = .replaced(path: path, jpegData: data)
                return .none

            case .uploadFailed(let id, let mode, let message):
                guard state.activeUploadID == id else { return .none }
                state.activeUploadID = nil
                state.drafts[mode] = .unchanged
                state.failureMessages[mode] = message
                return .none

            case .removeTapped:
                guard !state.isUploading else { return .none }
                let mode = state.selectedMode
                state.failureMessages[mode] = nil
                state.drafts[mode] = .removed
                return .none

            case .saveTapped, .closeTapped:
                return .none

            case .reset:
                state.selectedMode = state.targetType == .store ? .banner : .light
                state.drafts = [
                    .light: .unchanged,
                    .dark: .unchanged,
                    .banner: .unchanged,
                    .interstitial: .unchanged
                ]
                state.activeUploadID = nil
                state.selectedPhotoItem = nil
                state.isSaving = false
                state.failureMessages = [:]
                return .cancel(id: UploadTaskID.upload)

            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none

            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func uploadEffect(id: UUID, mode: Mode, data: Data, state: State) -> Effect<Action> {
        let useCase = uploadImageUseCase
        let target = ImageUploadTarget(
            type: state.targetType,
            id: state.targetID,
            variant: mode.uploadVariant(for: state.targetType)
        )
        return .run { send in
            do {
                let path = try await useCase.upload(target: target, jpegData: data)
                await send(.uploadCompleted(id: id, mode: mode, data: data, path: path))
            } catch {
                await send(.uploadFailed(
                    id: id,
                    mode: mode,
                    message: error.localizedDescription
                ))
            }
        }
        .cancellable(id: UploadTaskID.upload, cancelInFlight: true)
    }
}
