import Testing
@testable import iOSApp

struct APIErrorTests {
    @Test("HTTP 429のstatus codeを保持する")
    func preservesRateLimitStatus() {
        #expect(
            AppError(statusCode: 429, message: "Too Many Requests")
                == .be(.server(statusCode: 429, message: "Too Many Requests"))
        )
    }
}
