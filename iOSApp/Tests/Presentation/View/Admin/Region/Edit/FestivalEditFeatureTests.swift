import ComposableArchitecture
import Dependencies
import Foundation
import PhotosUI
import Shared
import Testing
@testable import iOSApp

struct FestivalEditFeatureTests {
    @Test("画像編集シートを閉じても下書きを保ち、既存 Festival PUT で確定する")
    @MainActor
    func retainsDraftUntilFestivalSave() async {
        let temporaryPath = "temporary/festivals/festival-1/light.jpg"
        let publicDarkPath = "https://cdn.example/festival-dark.jpg"
        let festival = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "Headquarters",
            base: Coordinate(latitude: 35, longitude: 139),
            image: ImagePath(light: "https://cdn.example/festival-light.jpg", dark: publicDarkPath)
        )
        var initialState = FestivalEditFeature.State(festival, appState: Shared(value: nil))
        initialState.imageEdit.lightDraft = .replaced(
            path: temporaryPath,
            jpegData: Data([0xFF, 0xD8, 0xFF, 0xD9])
        )
        let saveSpy = SaveFestivalUseCaseSpy()
        let store = TestStore(initialState: initialState) {
            FestivalEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveFestivalUseCaseKey.self] = saveSpy
        }

        await store.send(.imageEditTapped) {
            $0.isImageEditPresented = true
        }
        await store.send(.imageEdit(.modeSelected(.dark))) {
            $0.imageEdit.selectedMode = .dark
        }
        await store.send(.imageEditDismissTapped) {
            $0.isImageEditPresented = false
        }
        #expect(store.state.imageEdit.lightDraft == initialState.imageEdit.lightDraft)
        #expect(store.state.imageEdit.selectedMode == .dark)

        await store.send(.saveTapped) {
            $0.isLoading = true
        }
        await store.receive(.putReceived(.success)) {
            $0.isLoading = false
            $0.isImageEditPresented = false
        }
        await store.receive(.imageEdit(.reset)) {
            $0.imageEdit.selectedMode = .light
            $0.imageEdit.lightDraft = .unchanged
            $0.imageEdit.darkDraft = .unchanged
            $0.imageEdit.activeUploadID = nil
        }

        let calls = await saveSpy.calls
        #expect(calls.count == 1)
        #expect(calls.first?.festival.image == ImagePath(light: temporaryPath, dark: publicDarkPath))
        await store.finish()
    }

    @Test("Festival保存後に次の画像アップロードが失敗しても前回の一時パスを再送しない")
    @MainActor
    func failedSecondUploadDoesNotResendPreviousTemporaryPath() async {
        let oldImage = ImagePath(
            light: "https://cdn.example/old-light.jpg?v=3",
            dark: "https://cdn.example/old-dark.jpg?v=4"
        )
        let festival = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "Headquarters",
            base: Coordinate(latitude: 35, longitude: 139),
            image: oldImage
        )
        let temporaryA = "temporary/festivals/festival-1/light.jpg"
        let jpegA = Data([0xFF, 0xD8, 0xFF, 0xD9, 1])
        let jpegB = Data([0xFF, 0xD8, 0xFF, 0xD9, 2])
        var initialState = FestivalEditFeature.State(festival, appState: Shared(value: nil))
        initialState.imageEdit.lightDraft = .replaced(path: temporaryA, jpegData: jpegA)
        let saveSpy = SaveFestivalUseCaseSpy(failure: "save failed")
        let uploadSpy = UploadImageUseCaseSpy(preparedData: jpegB, path: temporaryA)
        let store = TestStore(initialState: initialState) {
            FestivalEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveFestivalUseCaseKey.self] = saveSpy
            $0[PhotoLibraryClientKey.self] = PhotoLibraryClientSpy(data: Data([9, 8, 7]))
            $0[UploadImageUseCaseKey.self] = uploadSpy
        }

        let saveError = AppError.system(.unexpected("save failed"))
        await store.send(.saveTapped) {
            $0.isLoading = true
        }
        await store.receive(.putReceived(.failure(saveError))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("保存に失敗しました。\(saveError.message)")
        }
        #expect(store.state.festival.image == oldImage)
        await store.send(.alert(.presented(.okTapped))) {
            $0.alert = nil
        }

        await uploadSpy.failUpload(with: "offline")
        let uploadID = UUID()
        await store.send(.imageEdit(.photoSelected(
            id: uploadID,
            item: PhotosPickerItem(itemIdentifier: "picked-b")
        ))) {
            $0.imageEdit.activeUploadID = uploadID
            $0.imageEdit.lightDraft = .loading
        }
        await store.receive(.imageEdit(.photoDataReceived(id: uploadID, mode: .light, data: Data([9, 8, 7])))) {
            $0.imageEdit.lightDraft = .preparing
        }
        await store.receive(.imageEdit(.jpegPrepared(id: uploadID, mode: .light, data: jpegB))) {
            $0.imageEdit.lightDraft = .uploading(jpegB)
        }
        await store.receive(.imageEdit(.uploadFailed(id: uploadID, mode: .light, message: "offline"))) {
            $0.imageEdit.activeUploadID = nil
            $0.imageEdit.lightDraft = .unchanged
            $0.imageEdit.failureMessages[.light] = "offline"
        }

        #expect(store.state.festival.image == oldImage)
        #expect(store.state.imageEdit.imagePath(applyingTo: oldImage) == oldImage)
        await store.send(.saveTapped) {
            $0.isLoading = true
        }
        await store.receive(.putReceived(.failure(saveError))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("保存に失敗しました。\(saveError.message)")
        }

        let calls = await saveSpy.calls
        #expect(calls.count == 2)
        #expect(calls[0].festival.image.light == temporaryA)
        #expect(calls[1].festival.image == oldImage)
        await store.finish()
    }
}
