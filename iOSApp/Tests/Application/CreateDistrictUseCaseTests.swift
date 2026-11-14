import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct CreateDistrictUseCaseTests {
    @Test("地区作成に成功するとサーバーが返したID・名称を保持する")
    func addsNewDistrictFromServer() async throws {
        let created = AppStateFixture.district(id: "created", name: "Created")
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: created, performances: [])
        )
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { CreateDistrictUseCase() }

        let result = try await useCase(
            name: "Client", email: "new@example.com",
            festivalId: "festival", appState: state
        )

        #expect(result.district == created)
        #expect(state.wrappedValue?.festivalState.districts.map(\.id) == ["district", "created"])
        #expect(await spy.recordedCalls() == ["create:Client:new@example.com:festival"])
    }

    @Test("他の祭典からのレスポンスは現在の祭典へ追加しない")
    func avoidsCrossFestivalMutation() async throws {
        let foreign = District(id: "foreign", name: "Foreign", festivalId: "another")
        let spy = DistrictDataFetcherSpy(response: DistrictPack(district: foreign, performances: []))
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { CreateDistrictUseCase() }

        _ = try await useCase(
            name: "Foreign", email: "f@example.com", festivalId: "another", appState: state
        )

        #expect(state.wrappedValue == original)
    }

    @Test("地区作成失敗時は追加せずエラーを伝える")
    func propagatesFailure() async {
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let spy = DistrictDataFetcherSpy(
            response: DistrictPack(district: AppStateFixture.district(), performances: []),
            shouldFail: true
        )
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[DistrictDataFetcherKey.self] = spy
        } operation: { CreateDistrictUseCase() }

        await #expect(throws: FetcherTestError.failed) {
            try await useCase(
                name: "District", email: "a@example.com",
                festivalId: "festival", appState: state
            )
        }
        #expect(state.wrappedValue == original)
    }
}
