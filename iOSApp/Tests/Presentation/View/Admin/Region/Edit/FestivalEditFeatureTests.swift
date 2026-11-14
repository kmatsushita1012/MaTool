import ComposableArchitecture
import Dependencies
import Foundation
import PhotosUI
import Shared
import SwiftUI
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
    @Test("空の祭典名は保存処理を開始せず入力エラーを表示する")
    @MainActor
    func emptyFestivalNameIsRejected() async {
        var initial = makeState()
        initial.festival.name = "  \n "
        let spy = SaveFestivalUseCaseSpy()
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveFestivalUseCaseKey.self] = spy
        }
        await store.send(.saveTapped) {
            $0.alert = AlertFeature.error("祭典名を1文字以上入力してください。")
        }
        #expect(!store.state.isLoading)
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

    @Test("本部名が空白だけなら保存せずエラーを表示する")
    @MainActor
    func emptyHeadquarterNameIsRejected() async {
        var initial = makeState()
        initial.festival.subname = "\n  "
        let spy = SaveFestivalUseCaseSpy()
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveFestivalUseCaseKey.self] = spy
        }
        await store.send(.saveTapped) {
            $0.alert = AlertFeature.error("本部名を1文字以上入力してください。")
        }
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

    @Test("祭典の所在地が未設定なら不完全な情報を送信しない")
    @MainActor
    func missingBaseIsRejected() async {
        var initial = makeState()
        initial.base = nil
        let spy = SaveFestivalUseCaseSpy()
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveFestivalUseCaseKey.self] = spy
        }
        await store.send(.saveTapped) {
            $0.alert = AlertFeature.error("本部所在地を設定してください。")
        }
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

    @Test("保存中の二重送信や画像編集ボタンは無視する")
    @MainActor
    func loadingPreventsDuplicateActions() async {
        var initial = makeState()
        initial.isLoading = true
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.saveTapped)
        await store.send(.imageEditTapped)
        #expect(store.state.isLoading)
        #expect(!store.state.isImageEditPresented)
        await store.finish()
    }

    @Test("画像アップロード中は画像編集シートを閉じない")
    @MainActor
    func imageUploadPreventsSheetDismissal() async {
        var initial = makeState()
        initial.isImageEditPresented = true
        initial.imageEdit.lightDraft = .uploading(Data([0xFF, 0xD8]))
        initial.imageEdit.activeUploadID = UUID()
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.imageEditDismissTapped)
        #expect(store.state.isImageEditPresented)
        await store.finish()
    }

    @Test("保存エラーのアラートを閉じても入力途中の祭典情報は維持する")
    @MainActor
    func errorAlertDismissalPreservesDraft() async {
        var initial = makeState()
        initial.festival.name = "draft"
        initial.alert = AlertFeature.error("offline")
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.alert(.presented(.okTapped))) {
            $0.alert = nil
        }
        #expect(store.state.festival.name == "draft")
        await store.finish()
    }

    @Test("本部所在地の編集画面には現在の所在地を引き継ぐ")
    @MainActor
    func baseEditorStartsAtCurrentCoordinate() async {
        let state = makeState()
        let expected = state.base
        let store = TestStore(initialState: state) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.baseTapped)
        #expect(store.state.destination?.base?.coordinate == expected)
        await store.finish()
    }

    private func makeState() -> FestivalEditFeature.State {
        FestivalEditFeature.State(
            AppStateFixture.festival(), appState: Shared<AppState?>(value: nil)
        )
    }

    @Test("祭典基準座標の編集完了は保存前の編集Stateへ反映する")
    @MainActor
    func finishedBaseEditUpdatesFestivalDraft() async {
        let origin = Coordinate(latitude: 34.5, longitude: 138.2)
        var initial = makeState()
        initial.destination = .base(.init(base: origin))
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.base(.doneTapped))))
        #expect(store.state.base == origin)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("交差点の編集完了は同じIDを更新し削除要求で一覧から取り除く")
    @MainActor
    func checkpointEditUpsertsAndDeletes() async {
        let checkpoint = Checkpoint(id: "checkpoint", name: "original", festivalId: "festival")
        var updated = checkpoint
        updated.name = "updated"
        var initial = makeState()
        initial.checkpoints = [checkpoint]
        initial.destination = .checkpoint(.init(title: "交差点", item: updated))
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.checkpoint(.doneTapped))))
        #expect(store.state.checkpoints.count == 1)
        #expect(store.state.checkpoints.first?.name == "updated")

        await store.send(.onCheckpointEdit(updated))
        await store.send(.destination(.presented(.checkpoint(.deleteTapped))))
        #expect(store.state.checkpoints.isEmpty)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("危険区域の正常な図形だけを保存し削除すると祭典ドラフトから除く")
    @MainActor
    func validHazardIsStoredAndCanBeDeleted() async {
        let hazard = HazardSection(
            id: "hazard", title: "注意箇所", festivalId: "festival",
            coordinates: [
                Coordinate(latitude: 35, longitude: 139),
                Coordinate(latitude: 35.1, longitude: 139.1)
            ]
        )
        var initial = makeState()
        initial.destination = .hazard(.init(hazard, mapRegion: makeRegion(hazard.coordinates)))
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.hazard(.doneTapped))))
        #expect(store.state.hazardSections.map(\.id) == ["hazard"])
        #expect(store.state.destination == nil)

        await store.send(.hazardTapped(hazard))
        await store.send(.destination(.presented(.hazard(.deleteTapped))))
        #expect(store.state.hazardSections.isEmpty)
        await store.finish()
    }

    @Test("未完成の危険区域を確定しようとしても祭典データへ反映しない")
    @MainActor
    func invalidHazardIsNotCommitted() async {
        let invalid = HazardSection(id: "invalid", title: "", festivalId: "festival")
        var initial = makeState()
        initial.destination = .hazard(.init(
            invalid, mapRegion: makeRegion(origin: AppStateFixture.festival().base, spanDelta: spanDelta)
        ))
        let store = TestStore(initialState: initial) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.hazard(.doneTapped))))
        #expect(store.state.hazardSections.isEmpty)
        #expect(store.state.destination?.hazard != nil)
        await store.finish()
    }

    @Test("本部所在地を未指定に戻した場合は祭典の登録位置を初期座標として開く")
    @MainActor
    func baseEditorFallsBackToFestivalLocation() async {
        var state = makeState()
        state.base = nil
        let store = TestStore(initialState: state) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.baseTapped)
        #expect(store.state.destination?.base?.region?.center.latitude
                == AppStateFixture.festival().base.latitude)
        await store.finish()
    }

    @Test("交差点追加は現在の祭典IDで新規Entityを作り、既存一覧を変更しない")
    @MainActor
    func checkpointCreationKeepsFestivalIdentity() async {
        let store = TestStore(initialState: makeState()) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.onCheckpointAdd)
        #expect(store.state.destination?.checkpoint?.item.festivalId == "festival")
        #expect(store.state.destination?.checkpoint?.item.id != nil)
        #expect(store.state.checkpoints.isEmpty)
        await store.finish()
    }

    @Test("危険区域の新規作成は祭典IDを持った空の下書きから開始する")
    @MainActor
    func hazardCreationStartsWithNoCoordinates() async {
        let store = TestStore(initialState: makeState()) {
            FestivalEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.hazardCreateTapped)
        #expect(store.state.destination?.hazard?.item.festivalId == "festival")
        #expect(store.state.destination?.hazard?.item.coordinates.isEmpty == true)
        #expect(store.state.hazardSections.isEmpty)
        await store.finish()
    }


}
