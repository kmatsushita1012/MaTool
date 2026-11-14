import Dependencies
import Shared

enum AdvertiserAuthControllerKey: DependencyKey {
    static let liveValue: any AdvertiserAuthControllerProtocol = AdvertiserAuthController()
}

extension DependencyValues {
    var advertiserAuthController: any AdvertiserAuthControllerProtocol {
        get { self[AdvertiserAuthControllerKey.self] }
        set { self[AdvertiserAuthControllerKey.self] = newValue }
    }
}

protocol AdvertiserAuthControllerProtocol: Sendable {
    func signUp(_ request: Request, next: Handler) async throws -> Response
    func confirmSignUp(_ request: Request, next: Handler) async throws -> Response
}

struct AdvertiserAuthController: AdvertiserAuthControllerProtocol {
    @Dependency(AdvertiserAuthUsecaseKey.self) var usecase

    func signUp(_ request: Request, next: Handler) async throws -> Response {
        try await usecase.signUp(request.body(as: AdvertiserSignUpRequest.self))
        return try .success()
    }

    func confirmSignUp(_ request: Request, next: Handler) async throws -> Response {
        try await usecase.confirmSignUp(request.body(as: AdvertiserConfirmSignUpRequest.self))
        return try .success()
    }
}
