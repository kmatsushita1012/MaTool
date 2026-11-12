@testable import iOSApp

actor PasswordChangeUseCaseSpy: ChangePasswordUseCaseProtocol {
    private(set) var calls: [(current: String, new: String)] = []
    private let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func callAsFunction(current: String, new: String) async throws {
        calls.append((current: current, new: new))
        if shouldFail {
            throw SpyInvocationError.unexpected("password change rejected")
        }
    }

    func recordedRequests() -> [(current: String, new: String)] { calls }
}
