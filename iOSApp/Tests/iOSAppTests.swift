import Testing
@testable import iOSApp


struct iOSAppTest {
    @Test func example() async throws {
        let sum = 1 + 2
        #expect(sum == 3)
    }

}
