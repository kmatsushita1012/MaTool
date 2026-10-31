import Dependencies
import Shared
import Testing
@testable import iOSApp

struct FetchFestivalListUseCaseTests {
    @Test("注入した祭典一覧SpyをUseCaseとして呼び出す")
    func injectedSpyReturnsEmptyFestivalList() async throws {
        let spy = FetchFestivalListUseCaseSpy(festivals: [])
        let useCase = withDependencies {
            $0.installTestSpies()
            $0[FetchFestivalListUseCaseKey.self] = spy
        } operation: {
            @Dependency(FetchFestivalListUseCaseKey.self) var useCase
            return useCase
        }

        let festivals = try await useCase()

        #expect(festivals.isEmpty)
        #expect(await spy.callCount == 1)
    }
}
