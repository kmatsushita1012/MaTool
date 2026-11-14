import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FetchFestivalListUseCaseTests {
    @Test("祭典一覧をDataFetcherに一度だけ問い合わせてその結果を返す")
    func delegatesToFestivalFetcher() async throws {
        let festival = AppStateFixture.festival()
        let pack = FestivalPack(festival: festival, checkpoints: [], hazardSections: [])
        let spy = FestivalDataFetcherSpy(response: pack, festivalList: [festival])
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[FestivalDataFetcherKey.self] = spy
        } operation: { FetchFestivalListUseCase() }

        #expect(try await useCase() == [festival])
        #expect(await spy.recordedCalls() == ["fetchAll"])
    }

    @Test("一覧取得失敗は空配列として隠さず呼び出し元へ返す")
    func propagatesFetcherFailure() async {
        let festival = AppStateFixture.festival()
        let pack = FestivalPack(festival: festival, checkpoints: [], hazardSections: [])
        let spy = FestivalDataFetcherSpy(response: pack, shouldFail: true)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[FestivalDataFetcherKey.self] = spy
        } operation: { FetchFestivalListUseCase() }

        await #expect(throws: FetcherTestError.failed) { try await useCase() }
        #expect(await spy.recordedCalls() == ["fetchAll"])
    }
}
