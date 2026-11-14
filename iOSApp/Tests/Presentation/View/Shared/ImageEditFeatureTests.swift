import ComposableArchitecture
import Dependencies
import Foundation
import PhotosUI
import Shared
import SwiftUI
import Testing
@testable import iOSApp

struct ImageEditFeatureTests {
    @Test("Light と Dark の画像下書きを独立して保持する")
    @MainActor
    func uploadsAndRemovesVariantsIndependently() async {
        let original = ImagePath(light: "https://cdn.example/light.jpg", dark: nil)
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let useCase = UploadImageUseCaseSpy(preparedData: jpeg, path: "temporary/festivals/festival-1/light.jpg")
        let photoLibrary = PhotoLibraryClientSpy(data: Data([1, 2, 3]))
        let id = UUID()
        let store = TestStore(
            initialState: ImageEditFeature.State(targetType: .festival, targetID: "festival-1", image: original)
        ) {
            ImageEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PhotoLibraryClientKey.self] = photoLibrary
            $0[UploadImageUseCaseKey.self] = useCase
        }

        await store.send(.photoSelected(id: id, item: PhotosPickerItem(itemIdentifier: "picked"))) {
            $0.activeUploadID = id
            $0.lightDraft = .loading
        }
        await store.receive(.photoDataReceived(id: id, mode: .light, data: Data([1, 2, 3]))) {
            $0.lightDraft = .preparing
        }
        await store.receive(.jpegPrepared(id: id, mode: .light, data: jpeg)) {
            $0.lightDraft = .uploading(jpeg)
        }
        await store.receive(.uploadCompleted(
            id: id,
            mode: .light,
            data: jpeg,
            path: "temporary/festivals/festival-1/light.jpg"
        )) {
            $0.activeUploadID = nil
            $0.lightDraft = .replaced(
                path: "temporary/festivals/festival-1/light.jpg",
                jpegData: jpeg
            )
        }

        #expect(store.state.originalImage == original)
        #expect(store.state.imagePath(applyingTo: original) == ImagePath(
            light: "temporary/festivals/festival-1/light.jpg",
            dark: nil
        ))
        #expect(await useCase.uploadCalls.count == 1)

        await store.send(.modeSelected(.dark)) {
            $0.selectedMode = .dark
        }
        await store.send(.removeTapped) {
            $0.darkDraft = .removed
        }
        #expect(store.state.imagePath(applyingTo: original) == ImagePath(
            light: "temporary/festivals/festival-1/light.jpg",
            dark: nil
        ))
        await store.finish()
    }

    @Test("新規画像のアップロード失敗は下書きを破棄して空に戻す")
    @MainActor
    func discardsFailedNewImageAndKeepsEmptyOriginal() async {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let useCase = UploadImageUseCaseSpy(
            preparedData: jpeg,
            path: "temporary/districts/district-1/light.jpg",
            uploadFailure: "S3 unavailable"
        )
        let store = TestStore(
            initialState: ImageEditFeature.State(
                targetType: .district,
                targetID: "district-1",
                image: ImagePath()
            )
        ) {
            ImageEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PhotoLibraryClientKey.self] = PhotoLibraryClientSpy(data: Data([4, 5]))
            $0[UploadImageUseCaseKey.self] = useCase
        }

        let firstID = UUID()
        await store.send(.photoSelected(id: firstID, item: PhotosPickerItem(itemIdentifier: "picked"))) {
            $0.activeUploadID = firstID
            $0.lightDraft = .loading
        }
        await store.receive(.photoDataReceived(id: firstID, mode: .light, data: Data([4, 5]))) {
            $0.lightDraft = .preparing
        }
        await store.receive(.jpegPrepared(id: firstID, mode: .light, data: jpeg)) {
            $0.lightDraft = .uploading(jpeg)
        }
        await store.receive(.uploadFailed(id: firstID, mode: .light, message: "S3 unavailable")) {
            $0.activeUploadID = nil
            $0.lightDraft = .unchanged
            $0.failureMessages[.light] = "S3 unavailable"
        }
        #expect(store.state.canSave)
        #expect(store.state.imagePath(applyingTo: ImagePath()) == ImagePath())
        #expect(store.state.previewData == nil)
        #expect(!store.state.hasImage)
        #expect(store.state.failureMessage(for: .light) == "S3 unavailable")
        #expect(await useCase.uploadCalls.count == 1)
        await store.finish()
    }

    @Test("既存画像のアップロード失敗は元の画像に戻す")
    @MainActor
    func restoresOriginalImageAfterFailedReplacement() async {
        let original = ImagePath(light: "https://cdn.example/light.jpg")
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let useCase = UploadImageUseCaseSpy(
            preparedData: jpeg,
            path: "temporary/districts/district-1/light.jpg",
            uploadFailure: "S3 unavailable"
        )
        let store = TestStore(
            initialState: ImageEditFeature.State(
                targetType: .district,
                targetID: "district-1",
                image: original
            )
        ) {
            ImageEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PhotoLibraryClientKey.self] = PhotoLibraryClientSpy(data: Data([4, 5]))
            $0[UploadImageUseCaseKey.self] = useCase
        }

        let id = UUID()
        await store.send(.photoSelected(id: id, item: PhotosPickerItem(itemIdentifier: "picked"))) {
            $0.activeUploadID = id
            $0.lightDraft = .loading
        }
        await store.receive(.photoDataReceived(id: id, mode: .light, data: Data([4, 5]))) {
            $0.lightDraft = .preparing
        }
        await store.receive(.jpegPrepared(id: id, mode: .light, data: jpeg)) {
            $0.lightDraft = .uploading(jpeg)
        }
        await store.receive(.uploadFailed(id: id, mode: .light, message: "S3 unavailable")) {
            $0.activeUploadID = nil
            $0.lightDraft = .unchanged
            $0.failureMessages[.light] = "S3 unavailable"
        }

        #expect(store.state.canSave)
        #expect(store.state.imagePath(applyingTo: original) == original)
        #expect(store.state.previewURL == original.light)
        #expect(store.state.hasImage)
        #expect(store.state.failureMessage(for: .light) == "S3 unavailable")

        await store.send(.removeTapped) {
            $0.lightDraft = .removed
            $0.failureMessages[.light] = nil
        }
        #expect(store.state.imagePath(applyingTo: original) == ImagePath())
        #expect(!store.state.hasImage)
        #expect(await useCase.uploadCalls.count == 1)
        await store.finish()
    }

    @Test("写真ピッカーからデータが得られない場合は元画像を保持し、原因を記録する")
    @MainActor
    func missingPickerDataKeepsOriginal() async {
        let original = ImagePath(light: "https://cdn.example/original.jpg")
        let photoLibrary = PhotoLibraryClientSpy(data: nil)
        let upload = UploadImageUseCaseSpy()
        let store = TestStore(initialState: ImageEditFeature.State(
            targetType: .district, targetID: "district-1", image: original
        )) {
            ImageEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PhotoLibraryClientKey.self] = photoLibrary
            $0[UploadImageUseCaseKey.self] = upload
        }

        let id = UUID()
        await store.send(.photoSelected(id: id, item: PhotosPickerItem(itemIdentifier: "nil"))) {
            $0.activeUploadID = id
            $0.lightDraft = .loading
        }
        await store.receive(.photoDataFailed(
            id: id, mode: .light, message: "画像を読み込めませんでした。"
        )) {
            $0.activeUploadID = nil
            $0.lightDraft = .unchanged
            $0.failureMessages[.light] = "画像を読み込めませんでした。"
        }
        #expect(store.state.imagePath(applyingTo: original) == original)
        #expect(store.state.canSave)
        #expect(await photoLibrary.loadCallCount == 1)
        #expect(await upload.prepareInputs.isEmpty)
        await store.finish()
    }

    @Test("写真へのアクセスで例外が発生した場合も元画像を保持して失敗理由を示す")
    @MainActor
    func pickerThrowPreservesDarkImage() async {
        let original = ImagePath(light: nil, dark: "https://cdn.example/dark.jpg")
        let photoLibrary = PhotoLibraryClientSpy(failure: "Library denied")
        let store = TestStore(initialState: ImageEditFeature.State(
            targetType: .district, targetID: "district-1", image: original
        )) {
            ImageEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PhotoLibraryClientKey.self] = photoLibrary
        }

        await store.send(.modeSelected(.dark)) { $0.selectedMode = .dark }
        let id = UUID()
        await store.send(.photoSelected(id: id, item: PhotosPickerItem(itemIdentifier: "denied"))) {
            $0.activeUploadID = id
            $0.darkDraft = .loading
        }
        await store.receive(.photoDataFailed(id: id, mode: .dark, message: "Library denied")) {
            $0.activeUploadID = nil
            $0.darkDraft = .unchanged
            $0.failureMessages[.dark] = "Library denied"
        }
        #expect(store.state.imagePath(applyingTo: original) == original)
        #expect(store.state.failureMessage(for: .light) == nil)
        #expect(store.state.previewURL == original.dark)
        await store.finish()
    }

    @Test("Dark画像のJPEG変換失敗ではアップロードせず、選択前の画像に戻す")
    @MainActor
    func jpegPreparationFailureRestoresDarkImage() async {
        let original = ImagePath(light: nil, dark: "https://cdn.example/dark.jpg")
        let photoData = Data([10, 20, 30])
        let upload = UploadImageUseCaseSpy(preparationFailure: "Cannot convert JPEG")
        let store = TestStore(initialState: ImageEditFeature.State(
            targetType: .festival, targetID: "festival-1", image: original
        )) {
            ImageEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PhotoLibraryClientKey.self] = PhotoLibraryClientSpy(data: photoData)
            $0[UploadImageUseCaseKey.self] = upload
        }

        await store.send(.modeSelected(.dark)) { $0.selectedMode = .dark }
        let id = UUID()
        await store.send(.photoSelected(id: id, item: PhotosPickerItem(itemIdentifier: "invalid"))) {
            $0.activeUploadID = id
            $0.darkDraft = .loading
        }
        await store.receive(.photoDataReceived(id: id, mode: .dark, data: photoData)) {
            $0.darkDraft = .preparing
        }
        await store.receive(.jpegPreparationFailed(
            id: id, mode: .dark, message: "Cannot convert JPEG"
        )) {
            $0.activeUploadID = nil
            $0.darkDraft = .unchanged
            $0.failureMessages[.dark] = "Cannot convert JPEG"
        }
        #expect(store.state.imagePath(applyingTo: original) == original)
        #expect(await upload.prepareInputs == [photoData])
        #expect(await upload.uploadCalls.isEmpty)
        await store.finish()
    }

    @Test("Dark画像のJPEG変換とアップロード成功はDarkだけを置き換える")
    @MainActor
    func successfulDarkUploadPreservesLightImage() async {
        let original = ImagePath(
            light: "https://cdn.example/light.jpg",
            dark: "https://cdn.example/dark.jpg"
        )
        let photoData = Data([11, 12])
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let path = "temporary/festivals/festival-1/dark.jpg"
        let upload = UploadImageUseCaseSpy(preparedData: jpeg, path: path)
        let store = TestStore(initialState: ImageEditFeature.State(
            targetType: .festival, targetID: "festival-1", image: original
        )) {
            ImageEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PhotoLibraryClientKey.self] = PhotoLibraryClientSpy(data: photoData)
            $0[UploadImageUseCaseKey.self] = upload
        }

        await store.send(.modeSelected(.dark)) { $0.selectedMode = .dark }
        let id = UUID()
        await store.send(.photoSelected(id: id, item: PhotosPickerItem(itemIdentifier: "dark"))) {
            $0.activeUploadID = id
            $0.darkDraft = .loading
        }
        await store.receive(.photoDataReceived(id: id, mode: .dark, data: photoData)) {
            $0.darkDraft = .preparing
        }
        await store.receive(.jpegPrepared(id: id, mode: .dark, data: jpeg)) {
            $0.darkDraft = .uploading(jpeg)
        }
        #expect(store.state.previewData == jpeg)
        await store.receive(.uploadCompleted(id: id, mode: .dark, data: jpeg, path: path)) {
            $0.activeUploadID = nil
            $0.darkDraft = .replaced(path: path, jpegData: jpeg)
        }
        #expect(store.state.imagePath(applyingTo: original) == ImagePath(
            light: original.light, dark: path
        ))
        #expect(await upload.uploadCalls.count == 1)
        #expect(await upload.uploadCalls.first?.target.variant == .dark)
        await store.finish()
    }

    @Test("Dark画像のアップロードに失敗した場合はLightに影響させず下書きを戻す")
    @MainActor
    func failedDarkUploadDoesNotChangeLight() async {
        let original = ImagePath(light: "https://cdn.example/light.jpg", dark: nil)
        let photoData = Data([11, 12])
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let upload = UploadImageUseCaseSpy(preparedData: jpeg, uploadFailure: "Upload unavailable")
        let store = TestStore(initialState: ImageEditFeature.State(
            targetType: .festival, targetID: "festival-1", image: original
        )) {
            ImageEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[PhotoLibraryClientKey.self] = PhotoLibraryClientSpy(data: photoData)
            $0[UploadImageUseCaseKey.self] = upload
        }

        await store.send(.modeSelected(.dark)) { $0.selectedMode = .dark }
        let id = UUID()
        await store.send(.photoSelected(id: id, item: PhotosPickerItem(itemIdentifier: "dark-fail"))) {
            $0.activeUploadID = id
            $0.darkDraft = .loading
        }
        await store.receive(.photoDataReceived(id: id, mode: .dark, data: photoData)) {
            $0.darkDraft = .preparing
        }
        await store.receive(.jpegPrepared(id: id, mode: .dark, data: jpeg)) {
            $0.darkDraft = .uploading(jpeg)
        }
        await store.receive(.uploadFailed(id: id, mode: .dark, message: "Upload unavailable")) {
            $0.activeUploadID = nil
            $0.darkDraft = .unchanged
            $0.failureMessages[.dark] = "Upload unavailable"
        }
        #expect(store.state.imagePath(applyingTo: original) == original)
        #expect(store.state.failureMessage(for: .dark) == "Upload unavailable")
        #expect(await upload.uploadCalls.count == 1)
        await store.finish()
    }

}
