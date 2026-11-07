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
    @Dependency(StoreRepositoryKey.self) var stores
    @Dependency(ImageStorageClientKey.self) var images

    func issue(_ request: ImageUploadURLRequest, user: UserRole) async throws -> ImageUploadURLResponse {
        guard request.contentType == "image/jpeg" else { throw Error.badRequest("JPEGのみアップロードできます。") }
        let target = request.target
        // Validate the type and variant before looking up the target.
        if target.type != .district { _ = try ImageObjectKey(target: target) }
        let key: ImageObjectKey
        switch target.type {
        case .festival:
            try requireRole(user, matches: .headquarter(target.id))
            guard try await festivals.get(id: target.id) != nil else { throw Error.notFound() }
            key = try ImageObjectKey(target: target)
        case .district:
            guard target.variant == .light || target.variant == .dark, !target.id.isEmpty else {
                throw Error.badRequest("画像の対象と種類が一致しません。")
            }
            try requireRole(user, matches: .district(target.id))
            guard let district = try await districts.get(id: target.id) else { throw Error.notFound() }
            key = try ImageObjectKey(target: target, festivalId: district.festivalId)
        case .store:
            guard case let .advertiser(ownerId) = user else {
                if user == .guest { throw Error.unauthorized("広告主としてログインしてください。") }
                throw Error.forbidden("広告主としてログインしてください。")
            }
            guard let store = try await stores.getOwned(id: target.id, ownerId: ownerId) else {
                throw Error.notFound("指定された店舗が見つかりません。")
            }
            guard store.moderationStatus == .approved else { throw Error.forbidden() }
            key = try ImageObjectKey(target: target)
        }
        let result = try await images.presign(key: key.temporary)
        return .init(url: result.url.absoluteString, path: key.temporary, expiresAt: result.expiresAt)
    }

    private func requireRole(_ user: UserRole, matches expected: UserRole) throws {
        if user == expected { return }
        if user == .guest { throw Error.unauthorized("ログインしてください。") }
        throw Error.forbidden("対象の管理権限がありません。")
    }
}
