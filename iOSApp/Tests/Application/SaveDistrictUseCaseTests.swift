import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SaveDistrictUseCaseTests {
    @Test("基本情報更新ではサーバーレスポンスで地区を置換する")
    func savesServerResponse() async throws {
        let submitted = AppStateFixture.district(name: "Submitted")
        let saved = AppStateFixture.district(name: "Normalized")
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: saved, performances: [])
        )
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { SaveDistrictUseCase() }

        let result = try await useCase(district: submitted, appState: state)

        #expect(result == saved)
        #expect(state.wrappedValue?.district(id: "district")?.name == "Normalized")
        #expect(await spy.recordedCalls() == ["updateCore:district"])
    }

    @Test("不一致の祭典レスポンスではローカルの地区を維持する")
    func wrongFestivalDoesNotMutate() async throws {
        let foreign = District(id: "district", name: "Foreign", festivalId: "another")
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: foreign, performances: [])
        )
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { SaveDistrictUseCase() }

        _ = try await useCase(district: AppStateFixture.district(), appState: state)

        #expect(state.wrappedValue == original)
    }

    @Test("通信失敗時にローカルの編集状態を壊さない")
    func failureKeepsLocalState() async {
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: AppStateFixture.district(), performances: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { SaveDistrictUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(district: AppStateFixture.district(), appState: state)
        }
        #expect(state.wrappedValue == original)
    }
}
