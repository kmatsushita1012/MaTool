import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct ReissueDistrictUseCaseTests {
    @Test("再発行成功時は返却された地区情報で現在の地区を置換する")
    func reissueUpdatesCurrentDistrict() async throws {
        let returned = AppStateFixture.district(name: "Reissued")
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: returned, performances: [])
        )
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { ReissueDistrictUseCase() }

        let result = try await useCase(
            districtId: "district", email: "new@example.com", appState: state
        )

        #expect(result.district == returned)
        #expect(state.wrappedValue?.district(id: "district")?.name == "Reissued")
        #expect(await spy.recordedCalls() == ["reissue:district:new@example.com"])
    }

    @Test("再発行失敗は状態を保持してエラーを返す")
    func failureKeepsState() async {
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: AppStateFixture.district(), performances: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { ReissueDistrictUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(
                districtId: "district", email: "a@example.com", appState: state
            )
        }
        #expect(state.wrappedValue == original)
    }
}
