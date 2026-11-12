import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SaveDistrictPackUseCaseTests {
    @Test("地区と余興情報を更新し、APIの正規化済み値を採用する")
    func appliesUpdatedDistrictAndPerformances() async throws {
        let returned = AppStateFixture.district(name: "Normalized")
        let performer = Performance(id: "performance", name: "Dance", districtId: returned.id)
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: returned, performances: [performer])
        )
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { SaveDistrictPackUseCase() }

        let result = try await useCase(
            district: AppStateFixture.district(name: "Submitted"),
            performances: [], appState: state
        )

        #expect(result.district == returned)
        #expect(state.wrappedValue?.district(id: "district")?.name == "Normalized")
        #expect(state.wrappedValue?.districtState?.performances == [performer])
        #expect(await spy.recordedCalls() == ["updatePack:district:0"])
    }

    @Test("別の地区が選択中なら余興一覧を差し替えない")
    func ignoresPerformancesOfUnselectedDistrict() async throws {
        let other = AppStateFixture.district(id: "another")
        let performer = Performance(id: "performance", districtId: other.id)
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: other, performances: [performer])
        )
        let original = AppStateFixture.state(
            districts: [AppStateFixture.district(), other]
        )
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { SaveDistrictPackUseCase() }

        _ = try await useCase(district: other, performances: [], appState: state)

        #expect(state.wrappedValue?.districtState?.districtId == "district")
        #expect(state.wrappedValue?.districtState?.performances.isEmpty == true)
    }

    @Test("更新失敗時は既存状態を保持する")
    func propagatesFailureWithoutChanges() async {
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: AppStateFixture.district(), performances: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { SaveDistrictPackUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(
                district: AppStateFixture.district(), performances: [], appState: state
            )
        }
        #expect(state.wrappedValue == original)
    }
}
