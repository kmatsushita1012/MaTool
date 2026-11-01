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

    @Test("S3 PUT 失敗は JPEG を保持し、再試行で一時キーを確定する")
    @MainActor
    func retriesFailedUploadWithoutSelectingAgain() async {
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
        await store.receive(.uploadFailed(id: firstID, mode: .light, data: jpeg, message: "S3 unavailable")) {
            $0.activeUploadID = nil
            $0.lightDraft = .failed(data: jpeg, message: "S3 unavailable")
        }
        #expect(!store.state.canSave)

        await useCase.failUpload(with: nil)
        let retryID = UUID()
        await store.send(.retryTapped(id: retryID)) {
            $0.activeUploadID = retryID
            $0.lightDraft = .uploading(jpeg)
        }
        await store.receive(.uploadCompleted(
            id: retryID,
            mode: .light,
            data: jpeg,
            path: "temporary/districts/district-1/light.jpg"
        )) {
            $0.activeUploadID = nil
            $0.lightDraft = .replaced(
                path: "temporary/districts/district-1/light.jpg",
                jpegData: jpeg
            )
        }

        #expect(store.state.canSave)
        #expect(await useCase.uploadCalls.count == 2)
        await store.finish()
    }
}
