import ComposableArchitecture
import Foundation
import PhotosUI
import Shared
import SwiftUI
import Testing
@testable import iOSApp

struct DistrictEditFeatureTests {
    @Test("町の基準座標は子画面で変更しても確定するまでは親の下書きに反映しない")
    @MainActor
    func childBaseEditDoesNotCommitUntilDone() async throws {
        let fixture = DistrictEditFixture()
        let oldCoordinate = Coordinate(latitude: 35, longitude: 139)
        let newCoordinate = Coordinate(latitude: 34, longitude: 138)
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.district.base = oldCoordinate
        initial.destination = .base(.init(base: oldCoordinate))
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.base(.mapTapped(newCoordinate)))))
        #expect(store.state.destination?.base?.coordinate == newCoordinate)
        #expect(store.state.district.base == oldCoordinate)

        let newAreaPoint = Coordinate(latitude: 35.2, longitude: 139.2)
        let previousArea = store.state.district.area
        await store.send(.areaTapped)
        await store.send(.destination(.presented(.area(.mapTapped(newAreaPoint)))))
        #expect(store.state.destination?.area?.coordinates.last == newAreaPoint)
        #expect(store.state.district.area == previousArea)

        await store.send(.performanceEditTapped(fixture.performance))
        await store.send(.destination(.presented(.performance(
            .binding(.set(\.item.name, "演目を編集中"))
        ))))
        #expect(store.state.destination?.performance?.item.name == "演目を編集中")
        #expect(store.state.performances == [fixture.performance])
        await store.finish()
    }

    @Test("地区名のフォームBindingは下書きだけを変更し保存APIは呼び出さない")
    @MainActor
    func districtNameBindingEditsDraftWithoutSaving() async throws {
        let fixture = DistrictEditFixture()
        let initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        let spy = SaveDistrictPackUseCaseSpy()
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictPackUseCaseKey.self] = spy
        }

        await store.send(.binding(.set(\.district.name, "地区名を編集中"))) {
            $0.district.name = "地区名を編集中"
        }
        #expect(!store.state.isLoading)
        #expect(store.state.district.name == "地区名を編集中")
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

    @Test("地区編集をキャンセルすると画像の一時ドラフトを破棄し保存処理を呼ばない")
    @MainActor
    func cancellationResetsImageDraftWithoutSaving() async throws {
        let fixture = DistrictEditFixture()
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.imageEdit.lightDraft = .replaced(
            path: "temporary/districts/district/light.jpg",
            jpegData: Data([0xFF, 0xD8, 0xFF, 0xD9])
        )
        initial.isImageEditPresented = true
        let saveSpy = SaveDistrictPackUseCaseSpy()
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictPackUseCaseKey.self] = saveSpy
        }

        await store.send(.cancelTapped) {
            $0.isImageEditPresented = false
        }
        await store.receive(.imageEdit(.reset)) {
            $0.imageEdit.lightDraft = .unchanged
        }
        #expect(await saveSpy.calls.isEmpty)
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("地区画像の下書きを既存 Pack PUT へ渡す")
    @MainActor
    func savesDistrictImageThroughExistingPack() async throws {
        let fixture = DistrictEditFixture()
        var initialState = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        let temporaryPath = "temporary/districts/district/dark.jpg"
        initialState.imageEdit.darkDraft = .replaced(
            path: temporaryPath,
            jpegData: Data([0xFF, 0xD8, 0xFF, 0xD9])
        )
        let saveSpy = SaveDistrictPackUseCaseSpy()
        let store = TestStore(initialState: initialState) {
            DistrictEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictPackUseCaseKey.self] = saveSpy
        }

        await store.send(.saveTapped) {
            $0.isLoading = true
        }
        await store.receive(.postReceived(.success)) {
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
        #expect(calls.first?.district.image == ImagePath(light: nil, dark: temporaryPath))
        await store.finish()
    }

    @Test("District保存後に次の画像アップロードが失敗しても前回の一時パスを再送しない")
    @MainActor
    func failedSecondUploadDoesNotResendPreviousTemporaryPath() async throws {
        let oldImage = ImagePath(
            light: "https://cdn.example/old-light.jpg?v=5",
            dark: "https://cdn.example/old-dark.jpg?v=6"
        )
        let fixture = DistrictEditFixture(image: oldImage)
        let district = fixture.district
        var initialState = try DistrictEditFeature.State(district, appState: fixture.appState)
        let temporaryA = "temporary/festivals/festival/districts/district/light.jpg"
        let jpegA = Data([0xFF, 0xD8, 0xFF, 0xD9, 1])
        let jpegB = Data([0xFF, 0xD8, 0xFF, 0xD9, 2])
        initialState.imageEdit.lightDraft = .replaced(path: temporaryA, jpegData: jpegA)

        let saveSpy = SaveDistrictPackUseCaseSpy(failure: "save failed")
        let uploadSpy = UploadImageUseCaseSpy(preparedData: jpegB, path: temporaryA)
        let store = TestStore(initialState: initialState) {
            DistrictEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictPackUseCaseKey.self] = saveSpy
            $0[PhotoLibraryClientKey.self] = PhotoLibraryClientSpy(data: Data([9, 8, 7]))
            $0[UploadImageUseCaseKey.self] = uploadSpy
        }

        let saveError = AppError.system(.unexpected("save failed"))
        await store.send(.saveTapped) {
            $0.isLoading = true
        }
        await store.receive(.postReceived(.failure(saveError))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("保存に失敗しました。\(saveError.message)")
        }
        #expect(store.state.district.image == oldImage)
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

        #expect(store.state.district.image == oldImage)
        #expect(store.state.imageEdit.imagePath(applyingTo: oldImage) == oldImage)
        await store.send(.saveTapped) {
            $0.isLoading = true
        }
        await store.receive(.postReceived(.failure(saveError))) {
            $0.isLoading = false
            $0.alert = AlertFeature.error("保存に失敗しました。\(saveError.message)")
        }

        let calls = await saveSpy.calls
        #expect(calls.count == 2)
        #expect(calls[0].district.image.light == temporaryA)
        #expect(calls[1].district.image == oldImage)
        await store.finish()
    }

    @Test("地区編集はAppStateのPerformanceと祭典基準座標を使う")
    @MainActor
    func 地区基準が未設定でも祭典基準で地図を開く() async throws {
        let fixture = DistrictEditFixture()
        let initialState = try DistrictEditFeature.State(
            fixture.district,
            appState: fixture.appState
        )
        let store = TestStore(initialState: initialState) {
            DistrictEditFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        #expect(store.state.performances == [fixture.performance])

        await store.send(.baseTapped) {
            $0.destination = .base(.init(
                coordinate: nil,
                regionOrigin: fixture.festivalBase,
                title: "会所位置"
            ))
        }
        #expect(store.state.destination?.base?.region?.center.latitude == fixture.festivalBase.latitude)
        #expect(store.state.destination?.base?.region?.center.longitude == fixture.festivalBase.longitude)
        await store.finish()
    }

    @Test("地区範囲編集は地区基準が未設定なら祭典基準を使う")
    @MainActor
    func 地区範囲を祭典基準で開く() async throws {
        let fixture = DistrictEditFixture()
        let initialState = try DistrictEditFeature.State(
            fixture.district,
            appState: fixture.appState
        )
        let store = TestStore(initialState: initialState) {
            DistrictEditFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.areaTapped) {
            $0.destination = .area(
                .init(coordinates: fixture.district.area, origin: fixture.festivalBase)
            )
        }
        #expect(store.state.destination?.area?.region?.center.latitude == fixture.festivalBase.latitude)
        #expect(store.state.destination?.area?.region?.center.longitude == fixture.festivalBase.longitude)
        await store.finish()
    }

    @Test("地区詳細が未ロードなら空のPerformance一覧で編集を開始しない")
    @MainActor
    func 地区詳細未ロード時に編集状態を作らない() async {
        let fixture = DistrictEditFixture()
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: fixture.festivalPack
        ))
        let store = TestStore(
            initialState: DistrictDashboardFeature.State(fixture.district, appState: appState)
        ) {
            DistrictDashboardFeature()
        } withDependencies: {
            $0.installTestSpies()
        }

        await store.send(.onEdit) {
            $0.alert = .error("情報の取得に失敗しました")
        }
        #expect(store.state.destination == nil)
        await store.finish()
    }
    @Test("詳細情報がない地区の編集Stateは作成せずnotFoundとして扱う")
    func initRejectsUnloadedDistrict() {
        let fixture = DistrictEditFixture()
        let unloaded = Shared<AppState?>(value: AppState(festivalPack: fixture.festivalPack))
        #expect(throws: PresentationError.self) {
            _ = try DistrictEditFeature.State(fixture.district, appState: unloaded)
        }
    }

    @Test("地区保存中の二重タップはUseCaseを再実行しない")
    @MainActor
    func savingPreventsDuplicateRequests() async throws {
        let fixture = DistrictEditFixture()
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.isLoading = true
        let spy = SaveDistrictPackUseCaseSpy()
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictPackUseCaseKey.self] = spy
        }

        await store.send(.saveTapped)
        await store.send(.imageEditTapped)
        #expect(store.state.isLoading)
        #expect(!store.state.isImageEditPresented)
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

    @Test("画像アップロード中のシートを閉じる要求は拒否する")
    @MainActor
    func uploadingImagePreventsDismissal() async throws {
        let fixture = DistrictEditFixture()
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.isImageEditPresented = true
        initial.imageEdit.lightDraft = .uploading(Data([0xFF, 0xD8]))
        initial.imageEdit.activeUploadID = UUID()
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.imageEditDismissTapped)
        #expect(store.state.isImageEditPresented)
        await store.finish()
    }

    @Test("アップロード中の画像は保存処理へ渡さず理由を表示する")
    @MainActor
    func savingPendingUploadIsRejected() async throws {
        let fixture = DistrictEditFixture()
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.imageEdit.darkDraft = .uploading(Data([0xFF, 0xD8]))
        initial.imageEdit.activeUploadID = UUID()
        let spy = SaveDistrictPackUseCaseSpy()
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: {
            $0.installTestSpies()
            $0[SaveDistrictPackUseCaseKey.self] = spy
        }
        await store.send(.saveTapped) {
            $0.alert = AlertFeature.error("画像のアップロードが完了するまで保存できません。")
        }
        #expect(await spy.calls.isEmpty)
        await store.finish()
    }

    @Test("既存の地区基準座標がある場合は祭典基準より優先する")
    @MainActor
    func existingDistrictBaseOverridesFestivalBase() async throws {
        let fixture = DistrictEditFixture()
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.district.base = Coordinate(latitude: 34, longitude: 138)
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.baseTapped) {
            $0.destination = .base(.init(base: Coordinate(latitude: 34, longitude: 138)))
        }
        #expect(store.state.destination?.base?.coordinate == initial.district.base)
        await store.finish()
    }

    @Test("演目追加は地区IDを引き継ぎ既存演目の編集とは区別する")
    @MainActor
    func performanceNavigationKeepsIdentity() async throws {
        let fixture = DistrictEditFixture()
        let initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.performanceAddTapped)
        #expect(store.state.destination?.performance != nil)
        await store.send(.performanceEditTapped(fixture.performance))
        #expect(store.state.destination?.performance?.item.id == fixture.performance.id)
        await store.finish()
    }

    @Test("保存失敗のアラートを閉じても入力した地区の内容を維持する")
    @MainActor
    func alertDismissPreservesDistrictDraft() async throws {
        let fixture = DistrictEditFixture()
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.district.name = "draft name"
        initial.alert = AlertFeature.error("offline")
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.alert(.presented(.okTapped))) {
            $0.alert = nil
        }
        #expect(store.state.district.name == "draft name")
        await store.finish()
    }

    @Test("地区基準座標の編集完了は変更座標を地区ドラフトへ反映する")
    @MainActor
    func finishedBaseEditUpdatesDistrictDraft() async throws {
        let fixture = DistrictEditFixture()
        let newBase = Coordinate(latitude: 34.5, longitude: 138.5)
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.destination = .base(.init(base: newBase))
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.base(.doneTapped))))
        #expect(store.state.district.base == newBase)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("地区領域の編集結果は元の地区に戻し、座標の並びを維持する")
    @MainActor
    func finishedAreaEditUpdatesDistrictArea() async throws {
        let fixture = DistrictEditFixture()
        let coords = [
            Coordinate(latitude: 35, longitude: 139),
            Coordinate(latitude: 35.1, longitude: 139.1),
            Coordinate(latitude: 35.2, longitude: 139)
        ]
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.destination = .area(.init(coordinates: coords, origin: fixture.festivalBase))
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.area(.doneTapped))))
        #expect(store.state.district.area == coords)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("演目の編集完了は同じIDの内容を更新し、削除ではリストから消す")
    @MainActor
    func performanceEditResultUpsertsAndDeletes() async throws {
        let fixture = DistrictEditFixture()
        var updated = fixture.performance
        updated.name = "updated"
        var initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        initial.destination = .performance(.init(item: updated))
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off

        await store.send(.destination(.presented(.performance(.doneTapped))))
        #expect(store.state.performances.count == 1)
        #expect(store.state.performances.first?.name == "updated")
        #expect(store.state.destination == nil)

        await store.send(.performanceEditTapped(updated))
        await store.send(.destination(.presented(.performance(.deleteTapped))))
        #expect(store.state.performances.isEmpty)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test("画像編集中でないときはシートを開閉でき、保存処理を開始しない")
    @MainActor
    func imageEditorTogglesWhenIdle() async throws {
        let fixture = DistrictEditFixture()
        let initialState = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        let store = TestStore(initialState: initialState) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }

        await store.send(.imageEditTapped) { $0.isImageEditPresented = true }
        await store.send(.imageEditDismissTapped) { $0.isImageEditPresented = false }
        #expect(!store.state.isLoading)
        await store.finish()
    }

    @Test("保存前に祭典の状態が失われたら座標編集画面を開かない")
    @MainActor
    func missingFestivalRejectsCoordinateNavigation() async throws {
        let fixture = DistrictEditFixture()
        let initial = try DistrictEditFeature.State(fixture.district, appState: fixture.appState)
        fixture.appState.withLock { $0 = nil }
        let store = TestStore(initialState: initial) {
            DistrictEditFeature()
        } withDependencies: { $0.installTestSpies() }
        store.exhaustivity = .off
        await store.send(.baseTapped)
        #expect(store.state.destination == nil)
        #expect(store.state.alert == .error("情報の取得に失敗しました"))
        await store.send(.alert(.presented(.okTapped)))
        await store.send(.areaTapped)
        #expect(store.state.destination == nil)
        #expect(store.state.alert == .error("情報の取得に失敗しました"))
        await store.finish()
    }

}

private struct DistrictEditFixture {
    let festivalBase: Coordinate
    let festival: Festival
    let festivalPack: LaunchFestivalPack
    let district: District
    let performance: Performance
    let appState: Shared<AppState?>

    init(image: ImagePath = .init()) {
        let festivalBase = Coordinate(latitude: 35, longitude: 139)
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: festivalBase
        )
        var district = District(id: "district", name: "District", festivalId: festival.id)
        district.image = image
        let performance = Performance(
            id: "performance",
            name: "Performance",
            districtId: district.id
        )
        let festivalPack = LaunchFestivalPack(
            festival: festival,
            year: 2026,
            districts: [district],
            periods: [],
            locations: [],
            checkpoints: [],
            hazardSections: []
        )
        self.festivalBase = festivalBase
        self.festival = festival
        self.district = district
        self.performance = performance
        self.festivalPack = festivalPack
        appState = Shared(value: AppState(
            festivalPack: festivalPack,
            districtPack: LaunchDistrictPack(
                performances: [performance],
                routes: [],
                points: [],
                passages: [],
                currentRouteId: nil
            ),
            districtId: district.id,
        ))
    }
}
