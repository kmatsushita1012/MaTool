import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct DeleteLocationUseCaseTests {
    @Test("位置情報削除は成功後に指定地区のみを除外する")
    func deleteRemovesOnlyChosenDistrict() async throws {
        let first = FloatLocation(
            id: "one", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let second = FloatLocation(
            id: "two", districtId: "other",
            coordinate: Coordinate(latitude: 36, longitude: 140)
        )
        let state = Shared<AppState?>(value: AppStateFixture.state(
            districts: [AppStateFixture.district(), AppStateFixture.district(id: "other")],
            locations: [first, second]
        ))
        let spy = LocationDataFetcherSpy(response: first)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { DeleteLocationUseCase() }

        try await useCase(districtId: "district", appState: state)

        #expect(state.wrappedValue?.festivalState.floatLocations.map(\.id) == ["two"])
        #expect(await spy.recordedCalls() == ["delete:district"])
    }

    @Test("削除失敗時は画面上の現在地情報を保持する")
    func failurePreservesLocation() async {
        let location = FloatLocation(
            id: "one", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let original = AppStateFixture.state(locations: [location])
        let state = Shared<AppState?>(value: original)
        let spy = LocationDataFetcherSpy(response: location, shouldFail: true)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { DeleteLocationUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(districtId: "district", appState: state)
        }
        #expect(state.wrappedValue == original)
    }

    @Test("セッションがない場合も削除APIは呼ぶがローカルには影響しない")
    func nilSessionDoesNotCreateState() async throws {
        let location = FloatLocation(
            id: "one", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let state = Shared<AppState?>(value: nil)
        let spy = LocationDataFetcherSpy(response: location)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { DeleteLocationUseCase() }

        try await useCase(districtId: "district", appState: state)
        #expect(state.wrappedValue == nil)
        #expect(await spy.recordedCalls() == ["delete:district"])
    }
}
