import Dependencies
import Shared

struct ImageUploadController: Sendable {
    @Dependency(ImageUploadUsecaseKey.self) var usecase

    func post(_ request: Request, next: Handler) async throws -> Response {
        guard let user = request.user, user != .guest else { throw Error.unauthorized() }
        guard let body = try? request.body(as: ImageUploadURLRequest.self) else { throw Error.badRequest() }
        let result = try await usecase.issue(body, user: user)
        return try .success(result)
    }
}
