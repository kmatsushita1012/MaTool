import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

struct FetchLocationUseCaseTests {
    @Test("取得した現在地一覧は地区単位の最新情報に置換する")
    func replacesLocationCacheWithServerResults() async throws {
        let first = FloatLocation(
            id: "before", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139),
            timestamp: Date(timeIntervalSince1970: 100)
        )
        let newer = FloatLocation(
            id: "after", districtId: "district",
            coordinate: Coordinate(latitude: 36, longitude: 140),
            timestamp: Date(timeIntervalSince1970: 200)
        )
        let spy = LocationDataFetcherSpy(response: newer, list: [newer, first])
        let state = Shared<AppState?>(value: AppStateFixture.state(locations: [first]))
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { FetchLocationUseCase() }

        let result = try await useCase(festivalId: "festival", appState: state)

        #expect(result == [newer, first])
        #expect(state.wrappedValue?.festivalState.floatLocations.map(\.id) == ["after"])
        #expect(await spy.recordedCalls() == ["fetchAll:festival"])
    }

    @Test("別祭典の応答で現在のAppStateを上書きしない")
    func doesNotChangeAnotherFestival() async throws {
        let location = FloatLocation(
            id: "foreign", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let spy = LocationDataFetcherSpy(response: location, list: [location])
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { FetchLocationUseCase() }

        #expect(try await useCase(festivalId: "unrelated", appState: state) == [location])
        #expect(state.wrappedValue == original)
    }

    @Test("通信エラー時に既存の位置情報を消去しない")
    func failurePreservesState() async {
        let location = FloatLocation(
            id: "cached", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let original = AppStateFixture.state(locations: [location])
        let state = Shared<AppState?>(value: original)
        let spy = LocationDataFetcherSpy(response: location, shouldFail: true)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { FetchLocationUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(festivalId: "festival", appState: state)
        }
        #expect(state.wrappedValue == original)
    }

    @Test("状態がnilならサーバー応答だけ返し復元しない")
    func nilStateIsNotRecreated() async throws {
        let location = FloatLocation(
            id: "loc", districtId: "district",
            coordinate: Coordinate(latitude: 35, longitude: 139)
        )
        let state = Shared<AppState?>(value: nil)
        let spy = LocationDataFetcherSpy(response: location, list: [location])
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[LocationDataFetcherKey.self] = spy
        } operation: { FetchLocationUseCase() }

        #expect(try await useCase(festivalId: "festival", appState: state) == [location])
        #expect(state.wrappedValue == nil)
    }
}
