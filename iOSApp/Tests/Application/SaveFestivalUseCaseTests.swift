import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SaveFestivalUseCaseTests {
    @Test("本部情報の更新はサーバーレスポンスで祭典情報を置換する")
    func adoptsReturnedFestivalPack() async throws {
        let submitted = AppStateFixture.festival()
        var responseFestival = submitted
        responseFestival.name = "Server normalized"
        let pack = FestivalPack(
            festival: responseFestival, checkpoints: [], hazardSections: []
        )
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let spy = FestivalDataFetcherSpy(response: pack)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[FestivalDataFetcherKey.self] = spy
        } operation: { SaveFestivalUseCase() }

        let result = try await useCase(
            festival: submitted, checkpoints: [], hazardSections: [], appState: state
        )

        #expect(result == pack)
        #expect(state.wrappedValue?.festivalState.festival.name == "Server normalized")
        #expect(await spy.recordedCalls() == ["update:festival:0:0"])
    }

    @Test("他祭典のレスポンスは現在の祭典の情報を上書きしない")
    func rejectsCrossFestivalResponse() async throws {
        let foreign = Festival(
            id: "foreign", name: "Other", subname: "Other",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let spy = FestivalDataFetcherSpy(
            response: FestivalPack(festival: foreign, checkpoints: [], hazardSections: [])
        )
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[FestivalDataFetcherKey.self] = spy
        } operation: { SaveFestivalUseCase() }

        _ = try await useCase(
            festival: AppStateFixture.festival(), checkpoints: [], hazardSections: [], appState: state
        )

        #expect(state.wrappedValue == original)
    }

    @Test("更新APIの失敗で既存の祭典情報を破壊しない")
    func propagatesFailure() async {
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = FestivalDataFetcherSpy(
            response: FestivalPack(
                festival: AppStateFixture.festival(), checkpoints: [], hazardSections: []
            ),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[FestivalDataFetcherKey.self] = spy
        } operation: { SaveFestivalUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(
                festival: AppStateFixture.festival(), checkpoints: [], hazardSections: [],
                appState: state
            )
        }
        #expect(state.wrappedValue == original)
    }
}
