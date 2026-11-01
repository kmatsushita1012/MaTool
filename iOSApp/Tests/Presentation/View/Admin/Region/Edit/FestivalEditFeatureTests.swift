import ComposableArchitecture
import Dependencies
import Foundation
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
            $0.festival.image = ImagePath(light: temporaryPath, dark: publicDarkPath)
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
}
