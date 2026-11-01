import Dependencies
import Shared

struct ImagePathFinalizer {
    @Dependency(ImageStorageClientKey.self) var imageStorage

    func finalize(
        incoming: ImagePath,
        current: ImagePath,
        type: ImageUploadTarget.Kind,
        id: String,
        festivalId: String? = nil
    ) async throws -> ImagePath {
        func value(_ candidate: String?, _ existing: String?, _ variant: ImageUploadTarget.Variant) async throws -> String? {
            guard let candidate else { return nil }
            if candidate == existing { return existing }
            let target = ImageUploadTarget(type: type, id: id, variant: variant)
            let keys = try ImageObjectKey(target: target, festivalId: festivalId)
            guard candidate == keys.temporary else { throw Error.badRequest("画像パスが不正です。") }
            return try await imageStorage.publish(temporaryKey: keys.temporary, permanentKey: keys.permanent, currentURL: existing)
        }
        let light = try await value(incoming.light, current.light, .light)
        let dark = try await value(incoming.dark, current.dark, .dark)
        return .init(light: light, dark: dark)
    }
}
