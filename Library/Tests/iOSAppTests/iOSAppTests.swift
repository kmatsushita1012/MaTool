import Testing
@testable import iOSApp

struct iOSAppTests{
    @Test func test_成功する() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let count = 5
        #expect(count == 5)
    }

    @Test func test＿失敗する() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let count = 5
        #expect(count == 4)
    }
}


