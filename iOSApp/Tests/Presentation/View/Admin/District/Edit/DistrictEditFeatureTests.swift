import ComposableArchitecture
import Foundation
import PhotosUI
import Shared
import SwiftUI
import Testing
@testable import iOSApp

struct DistrictEditFeatureTests {
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
        let fixture = DistrictEditFixture()
        let oldImage = ImagePath(
            light: "https://cdn.example/old-light.jpg?v=5",
            dark: "https://cdn.example/old-dark.jpg?v=6"
        )
        var district = fixture.district
        district.image = oldImage
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
            $0.destination = .base(.init(origin: fixture.festivalBase))
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
            festivalPack: fixture.festivalPack,
            year: 2026
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
}

private struct DistrictEditFixture {
    let festivalBase: Coordinate
    let festival: Festival
    let festivalPack: LaunchFestivalPack
    let district: District
    let performance: Performance
    let appState: Shared<AppState?>

    init() {
        let festivalBase = Coordinate(latitude: 35, longitude: 139)
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: festivalBase
        )
        let district = District(id: "district", name: "District", festivalId: festival.id)
        let performance = Performance(
            id: "performance",
            name: "Performance",
            districtId: district.id
        )
        let festivalPack = LaunchFestivalPack(
            festival: festival,
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
            year: 2026
        ))
    }
}
