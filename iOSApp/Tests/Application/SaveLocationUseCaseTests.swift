import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct SaveLocationUseCaseTests {
    @Test("APIが返した正規化後の位置情報をAppStateに登録する")
    func storesOnlyServerResponse() async throws {
        let before = FloatLocation(
            id: "client-id", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let after = FloatLocation(
            id: "server-id", districtId: "district",
            coordinate: Coordinate(latitude: 36, longitude: 140)
        )
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let spy = LocationDataFetcherSpy(response: after)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { SaveLocationUseCase() }

        let response = try await useCase(before, appState: state)

        #expect(response == after)
        #expect(state.wrappedValue?.floatLocation(for: "district")?.id == "server-id")
        #expect(await spy.recordedCalls() == ["update:client-id"])
    }

    @Test("存在しない地区を対象とする応答はローカルへ追加しない")
    func rejectsUnknownDistrictFromLocalState() async throws {
        let foreign = FloatLocation(
            id: "foreign", districtId: "other",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = LocationDataFetcherSpy(response: foreign)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { SaveLocationUseCase() }

        #expect(try await useCase(foreign, appState: state) == foreign)
        #expect(state.wrappedValue == original)
    }

    @Test("保存に失敗したら以前の位置情報を維持する")
    func failureDoesNotMutate() async {
        let existing = FloatLocation(
            id: "old", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let original = AppStateFixture.state(locations: [existing])
        let state = Shared<AppState?>(value: original)
        let spy = LocationDataFetcherSpy(response: existing, shouldFail: true)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { SaveLocationUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(existing, appState: state)
        }
        #expect(state.wrappedValue == original)
    }
}
