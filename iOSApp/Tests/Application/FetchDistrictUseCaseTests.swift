import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FetchDistrictUseCaseTests {
    @Test("地区IDをDataFetcherへ正しく渡してPackを返す")
    func delegatesFetchByDistrictId() async throws {
        let expected = DistrictPack(
            district: AppStateFixture.district(),
            performances: [Performance(id: "performance", districtId: "district")]
        )
        let spy = DistrictDataFetcherSpy(response: expected)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { FetchDistrictUseCase() }

        let pack = try await useCase(districtId: "district")

        #expect(pack == expected)
        #expect(await spy.recordedCalls() == ["fetch:district"])
    }

    @Test("取得失敗を空のPackへ変換せず伝える")
    func propagatesFailure() async {
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: AppStateFixture.district(), performances: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { FetchDistrictUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(districtId: "district")
        }
    }
}
