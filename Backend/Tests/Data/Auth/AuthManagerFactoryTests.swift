import Dependencies
import Shared
import Testing
@testable import Backend

struct AuthManagerFactoryTests {
    @Test("DIで差し替えたAuthManagerFactoryだけを呼び出し、Cognitoの実接続を行わない")
    func factoryOverrideCreatesExpectedManager() async throws {
        let spy = AuthManagerMock(
            getUserNameHandler: { username in .district(username) }
        )
        let manager = try await withDependencies {
            $0[AuthManagerFactoryKey.self] = { spy }
        } operation: {
            @Dependency(AuthManagerFactoryKey.self) var factory
            return try await factory()
        }

        let role = try await manager.get(username: "district-1")

        #expect(role == .district("district-1"))
        #expect(spy.getUserNameCallCount == 1)
    }
}
