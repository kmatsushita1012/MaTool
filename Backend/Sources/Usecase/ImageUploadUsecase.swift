import Dependencies
import Shared

enum ImageUploadUsecaseKey: DependencyKey {
    static let liveValue: any ImageUploadUsecaseProtocol = ImageUploadUsecase()
}

protocol ImageUploadUsecaseProtocol: Sendable {
    func issue(_ request: ImageUploadURLRequest, user: UserRole) async throws -> ImageUploadURLResponse
}

struct ImageUploadUsecase: ImageUploadUsecaseProtocol {
    @Dependency(FestivalRepositoryKey.self) var festivals
    @Dependency(DistrictRepositoryKey.self) var districts
    @Dependency(ImageStorageClientKey.self) var images

    func issue(_ request: ImageUploadURLRequest, user: UserRole) async throws -> ImageUploadURLResponse {
        guard request.contentType == "image/jpeg" else { throw Error.badRequest("JPEGのみアップロードできます。") }
        let target = request.target
        // Validate the type and variant before looking up the target.
        if target.type != .district { _ = try ImageObjectKey(target: target) }
        let key: ImageObjectKey
        switch target.type {
        case .festival:
            guard try await festivals.get(id: target.id) != nil else { throw Error.notFound() }
            guard user == .headquarter(target.id) else { throw Error.forbidden() }
            key = try ImageObjectKey(target: target)
        case .district:
            guard target.variant == .light || target.variant == .dark, !target.id.isEmpty else {
                throw Error.badRequest("画像の対象と種類が一致しません。")
            }
            guard let district = try await districts.get(id: target.id) else { throw Error.notFound() }
            guard user == .district(target.id) else { throw Error.forbidden() }
            key = try ImageObjectKey(target: target, festivalId: district.festivalId)
        case .store:
            // Store ownership is introduced with the advertising backend.
            throw Error.forbidden()
        }
        let result = try await images.presign(key: key.temporary)
        return .init(url: result.url.absoluteString, path: key.temporary, expiresAt: result.expiresAt)
    }
}
