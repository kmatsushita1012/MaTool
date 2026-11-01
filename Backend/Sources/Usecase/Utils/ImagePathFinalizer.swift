import Dependencies
import Shared

struct ImagePathFinalizer {
    @Dependency(ImageStorageClientKey.self) var imageStorage

    func finalizeStoreImages(
        incomingBanner: String?,
        currentBanner: String?,
        incomingInterstitial: String?,
        currentInterstitial: String?,
        storeId: Store.ID
    ) async throws -> (banner: String?, interstitial: String?) {
        struct PendingImage {
            let placement: StoreAdPlacement
            let temporaryKey: String
            let permanentKey: String
            let currentURL: String?
        }

        var pending: [PendingImage] = []

        func prepare(_ incoming: String?, _ current: String?, _ placement: StoreAdPlacement) throws -> String? {
            guard let incoming else { return nil }
            if incoming == current { return current }

            let variant: ImageUploadTarget.Variant = switch placement {
            case .banner: .banner
            case .interstitial: .interstitial
            }
            let key = try ImageObjectKey(target: .init(type: .store, id: storeId, variant: variant))
            guard incoming == key.temporary else { throw Error.badRequest("画像パスが不正です。") }
            pending.append(PendingImage(
                placement: placement,
                temporaryKey: key.temporary,
                permanentKey: key.permanent,
                currentURL: current
            ))
            return nil
        }

        var banner = try prepare(incomingBanner, currentBanner, .banner)
        var interstitial = try prepare(incomingInterstitial, currentInterstitial, .interstitial)

        // Validate both changed images before copying either one to a public key.
        for image in pending {
            try await imageStorage.validateTemporaryImage(key: image.temporaryKey)
        }

        for image in pending {
            let publishedURL = try await imageStorage.publish(
                temporaryKey: image.temporaryKey,
                permanentKey: image.permanentKey,
                currentURL: image.currentURL
            )
            switch image.placement {
            case .banner:
                banner = publishedURL
            case .interstitial:
                interstitial = publishedURL
            }
        }
        return (banner, interstitial)
    }

    func finalize(
        incoming: ImagePath,
        current: ImagePath,
        type: ImageUploadTarget.Kind,
        id: String,
        festivalId: String? = nil
    ) async throws -> ImagePath {
        struct PendingImage {
            let variant: ImageUploadTarget.Variant
            let temporaryKey: String
            let permanentKey: String
            let currentURL: String?
        }

        var pending: [PendingImage] = []

        func prepare(_ candidate: String?, _ existing: String?, _ variant: ImageUploadTarget.Variant) throws -> String? {
            guard let candidate else { return nil }
            if candidate == existing { return existing }
            let target = ImageUploadTarget(type: type, id: id, variant: variant)
            let keys = try ImageObjectKey(target: target, festivalId: festivalId)
            guard candidate == keys.temporary else { throw Error.badRequest("画像パスが不正です。") }
            pending.append(PendingImage(
                variant: variant,
                temporaryKey: keys.temporary,
                permanentKey: keys.permanent,
                currentURL: existing
            ))
            return existing
        }

        var light = try prepare(incoming.light, current.light, .light)
        var dark = try prepare(incoming.dark, current.dark, .dark)

        // Validate every changed candidate before publishing any permanent object.
        for image in pending {
            try await imageStorage.validateTemporaryImage(key: image.temporaryKey)
        }

        for image in pending {
            let publishedURL = try await imageStorage.publish(
                temporaryKey: image.temporaryKey,
                permanentKey: image.permanentKey,
                currentURL: image.currentURL
            )
            switch image.variant {
            case .light:
                light = publishedURL
            case .dark:
                dark = publishedURL
            case .banner, .interstitial:
                throw Error.badRequest("画像のvariantが不正です。")
            }
        }
        return .init(light: light, dark: dark)
    }
}
