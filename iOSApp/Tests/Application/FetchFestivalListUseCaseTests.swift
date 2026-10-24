import Shared
import Testing
@testable import iOSApp

struct FetchFestivalListUseCaseTests {
    @Test("テスト用の祭典一覧UseCaseは空の一覧を返す")
    func testValueReturnsEmptyFestivalList() async throws {
        let festivals = try await FetchFestivalListUseCaseKey.testValue()

        #expect(festivals.isEmpty)
    }
}

private struct EmptyFestivalListUseCase: FetchFestivalListUseCaseProtocol {
    func callAsFunction() async throws -> [Festival] {
        []
    }
}

extension FetchFestivalListUseCaseKey {
    static let testValue: any FetchFestivalListUseCaseProtocol = EmptyFestivalListUseCase()
}
