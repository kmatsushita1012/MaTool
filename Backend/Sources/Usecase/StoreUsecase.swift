import Dependencies
import Foundation
import Shared

enum StoreUsecaseKey: DependencyKey {
    static let liveValue: any StoreUsecaseProtocol = StoreUsecase()
}

protocol StoreUsecaseProtocol: Sendable {
    func storesOwned(by user: UserRole) async throws -> [Store]
    func create(festivalId: Festival.ID, request: StoreCreateRequest, user: UserRole) async throws -> Store
    func get(id: Store.ID, user: UserRole) async throws -> Store
    func put(id: Store.ID, request: Store, user: UserRole) async throws -> Store
    func publicStores(in festivalId: Festival.ID) async throws -> [PublicStore]
}

struct StoreUsecase: StoreUsecaseProtocol {
    @Dependency(\.advertisingEnvironment) var advertisingEnvironment
    @Dependency(StoreRepositoryKey.self) var stores
    @Dependency(FestivalRepositoryKey.self) var festivals

    func storesOwned(by user: UserRole) async throws -> [Store] {
        try await stores.storesOwned(by: advertiserId(user))
    }

    func create(festivalId: Festival.ID, request: StoreCreateRequest, user: UserRole) async throws -> Store {
        let ownerId = try advertiserId(user)
        try validate(name: request.name, address: request.address, businessHours: request.businessHours, description: request.description, coordinate: request.coordinate)
        guard try await festivals.get(id: festivalId) != nil else { throw Error.notFound("指定された祭典が見つかりません。") }

        let current = try await stores.storesOwned(by: ownerId)
        guard current.count < advertisingEnvironment.maximumStoresPerOwner else {
            throw Error.conflict("登録できる店舗数の上限に達しています。")
        }

        let now = Date()
        let item = Store(
            id: UUID().uuidString.lowercased(),
            festivalId: festivalId,
            ownerId: ownerId,
            purchaseAccountToken: UUID(),
            name: request.name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: request.address.trimmingCharacters(in: .whitespacesAndNewlines),
            coordinate: request.coordinate,
            businessHours: request.businessHours.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmedOptional(request.description),
            createdAt: now,
            updatedAt: now
        )
        try await stores.create(item)
        return item
    }

    func get(id: Store.ID, user: UserRole) async throws -> Store {
        let ownerId = try advertiserId(user)
        guard let item = try await stores.getOwned(id: id, ownerId: ownerId) else {
            throw Error.notFound("指定された店舗が見つかりません。")
        }
        return item
    }

    func put(id: Store.ID, request: Store, user: UserRole) async throws -> Store {
        let ownerId = try advertiserId(user)
        guard id == request.id else { throw Error.badRequest("URLの店舗IDと送信データの店舗IDが一致しません。") }
        guard let current = try await stores.getOwned(id: id, ownerId: ownerId) else {
            throw Error.notFound("指定された店舗が見つかりません。")
        }
        guard request.ownerId == current.ownerId,
              request.festivalId == current.festivalId,
              request.purchaseAccountToken == current.purchaseAccountToken,
              request.moderationStatus == current.moderationStatus,
              request.createdAt == current.createdAt else {
            throw Error.badRequest("サーバー管理項目は変更できません。")
        }
        try validate(name: request.name, address: request.address, businessHours: request.businessHours, description: request.description, coordinate: request.coordinate)

        let imagePaths: (banner: String?, interstitial: String?)
        if current.moderationStatus == .approved {
            imagePaths = try await ImagePathFinalizer().finalizeStoreImages(
                incomingBanner: request.bannerImagePath,
                currentBanner: current.bannerImagePath,
                incomingInterstitial: request.interstitialImagePath,
                currentInterstitial: current.interstitialImagePath,
                storeId: id
            )
        } else {
            guard request.bannerImagePath == current.bannerImagePath,
                  request.interstitialImagePath == current.interstitialImagePath else {
                throw Error.forbidden("掲載停止中は広告画像を変更できません。")
            }
            imagePaths = (current.bannerImagePath, current.interstitialImagePath)
        }

        let now = Date()
        let imagePathsChanged = request.bannerImagePath != current.bannerImagePath
            || request.interstitialImagePath != current.interstitialImagePath
        let updated = Store(
            id: current.id,
            festivalId: current.festivalId,
            ownerId: current.ownerId,
            purchaseAccountToken: current.purchaseAccountToken,
            name: request.name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: request.address.trimmingCharacters(in: .whitespacesAndNewlines),
            coordinate: request.coordinate,
            businessHours: request.businessHours.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmedOptional(request.description),
            bannerImagePath: imagePaths.banner,
            interstitialImagePath: imagePaths.interstitial,
            ownerPaused: request.ownerPaused,
            moderationStatus: current.moderationStatus,
            createdAt: current.createdAt,
            updatedAt: now
        )
        return try await stores.updateEditableFields(updated, requireApproved: imagePathsChanged)
    }

    func publicStores(in festivalId: Festival.ID) async throws -> [PublicStore] {
        try await stores.stores(in: festivalId)
            .filter { $0.moderationStatus == .approved }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { PublicStore(store: $0, hideImages: $0.ownerPaused) }
    }

    private func advertiserId(_ user: UserRole) throws -> String {
        switch user {
        case let .advertiser(id) where !id.isEmpty:
            return id
        case .guest:
            throw Error.unauthorized("広告主としてログインしてください。")
        default:
            throw Error.forbidden("広告主としてログインしてください。")
        }
    }

    private func validate(name: String, address: String, businessHours: String, description: String?, coordinate: Coordinate) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let hours = businessHours.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120,
              !address.isEmpty, address.count <= 300,
              hours.count <= 300,
              (description?.count ?? 0) <= 2_000,
              (-90...90).contains(coordinate.latitude), (-180...180).contains(coordinate.longitude) else {
            throw Error.badRequest("店舗情報が不正です。")
        }
    }

    private func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

}
