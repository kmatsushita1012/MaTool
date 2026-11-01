import ComposableArchitecture
import Foundation
import PhotosUI
import Shared
import SwiftUI

@Reducer
struct ImageEditFeature {
    enum Mode: Equatable, Hashable, Sendable {
        case light
        case dark

        var uploadVariant: ImageUploadTarget.Variant {
            switch self {
            case .light: .light
            case .dark: .dark
            }
        }
    }

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
        var selectedMode: Mode = .light
        var lightDraft: Draft = .unchanged
        var darkDraft: Draft = .unchanged
        var activeUploadID: UUID?
        var failureMessages: [Mode: String] = [:]

        init(targetType: ImageUploadTarget.Kind, targetID: String, image: ImagePath) {
            self.targetType = targetType
            self.targetID = targetID
            self.originalImage = image
        }

        var isUploading: Bool { activeUploadID != nil }

        var canSave: Bool { !isUploading }

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
                light: path(for: lightDraft, originalPath: image.light),
                dark: path(for: darkDraft, originalPath: image.dark)
            )
        }

        func draft(for mode: Mode) -> Draft {
            mode == .light ? lightDraft : darkDraft
        }

        func failureMessage(for mode: Mode) -> String? {
            failureMessages[mode]
        }

        mutating func setDraft(_ draft: Draft, for mode: Mode) {
            switch mode {
            case .light: lightDraft = draft
            case .dark: darkDraft = draft
            }
        }

        private func imagePath(for mode: Mode) -> String? {
            switch mode {
            case .light: originalImage.light
            case .dark: originalImage.dark
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

    enum Action: Equatable {
        case modeSelected(Mode)
        case photoSelected(id: UUID, item: PhotosPickerItem)
        case photoDataReceived(id: UUID, mode: Mode, data: Data)
        case photoDataFailed(id: UUID, mode: Mode, message: String)
        case jpegPrepared(id: UUID, mode: Mode, data: Data)
        case jpegPreparationFailed(id: UUID, mode: Mode, message: String)
        case uploadCompleted(id: UUID, mode: Mode, data: Data, path: String)
        case uploadFailed(id: UUID, mode: Mode, message: String)
        case removeTapped
        case reset
    }

    @Dependency(PhotoLibraryClientKey.self) var photoLibraryClient
    @Dependency(UploadImageUseCaseKey.self) var uploadImageUseCase

    private enum UploadTaskID: Hashable { case upload }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .modeSelected(let mode):
                guard !state.isUploading else { return .none }
                state.selectedMode = mode
                return .none

            case .photoSelected(let id, let item):
                guard !state.isUploading else { return .none }
                let mode = state.selectedMode
                state.failureMessages[mode] = nil
                state.activeUploadID = id
                state.setDraft(.loading, for: mode)
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
                state.setDraft(.preparing, for: mode)
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
                state.setDraft(.unchanged, for: mode)
                state.failureMessages[mode] = message
                return .none

            case .jpegPrepared(let id, let mode, let data):
                guard state.activeUploadID == id else { return .none }
                state.setDraft(.uploading(data), for: mode)
                return uploadEffect(id: id, mode: mode, data: data, state: state)

            case .uploadCompleted(let id, let mode, let data, let path):
                guard state.activeUploadID == id else { return .none }
                state.activeUploadID = nil
                state.setDraft(.replaced(path: path, jpegData: data), for: mode)
                return .none

            case .uploadFailed(let id, let mode, let message):
                guard state.activeUploadID == id else { return .none }
                state.activeUploadID = nil
                state.setDraft(.unchanged, for: mode)
                state.failureMessages[mode] = message
                return .none

            case .removeTapped:
                guard !state.isUploading else { return .none }
                state.failureMessages[state.selectedMode] = nil
                state.setDraft(.removed, for: state.selectedMode)
                return .none

            case .reset:
                state.selectedMode = .light
                state.lightDraft = .unchanged
                state.darkDraft = .unchanged
                state.activeUploadID = nil
                state.failureMessages = [:]
                return .cancel(id: UploadTaskID.upload)
            }
        }
    }

    private func uploadEffect(id: UUID, mode: Mode, data: Data, state: State) -> Effect<Action> {
        let useCase = uploadImageUseCase
        let target = ImageUploadTarget(type: state.targetType, id: state.targetID, variant: mode.uploadVariant)
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
