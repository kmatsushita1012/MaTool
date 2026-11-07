import Dependencies
import Foundation
import Shared

enum AdvertisementUsecaseKey: DependencyKey {
    static let liveValue: any AdvertisementUsecaseProtocol = AdvertisementUsecase()
}

protocol AdvertisementUsecaseProtocol: Sendable {
    func next(festivalId: Festival.ID, placement: StoreAdPlacement) async throws -> AdCandidate?
    func report(_ request: AdvertisementReportRequest) async throws
}

struct AdvertisementUsecase: AdvertisementUsecaseProtocol {
    @Dependency(StoreRepositoryKey.self) var stores
    @Dependency(CreditRepositoryKey.self) var credits
    @Dependency(FestivalRepositoryKey.self) var festivals
    @Dependency(ReportNotificationClientKey.self) var notifications

    func next(festivalId: Festival.ID, placement: StoreAdPlacement) async throws -> AdCandidate? {
        guard try await festivals.get(id: festivalId) != nil else { throw Error.notFound("指定された祭典が見つかりません。") }
        let candidates = try await stores.stores(in: festivalId)
            .filter { $0.moderationStatus == .approved && !$0.ownerPaused }
            .compactMap { store -> (Store, String)? in
                let image = placement == .banner ? store.bannerImagePath : store.interstitialImagePath
                guard let image else { return nil }
                return (store, image)
            }

        var eligible: [(Store, String)] = []
        for (store, image) in candidates {
            guard let account = try await credits.get(storeId: store.id), account.balance >= placement.creditCost else { continue }
            eligible.append((store, image))
        }
        guard let (selected, imagePath) = eligible.randomElement() else { return nil }

        let now = Date()
        let impressionId = UUID().uuidString.lowercased()
        let payload = ImpressionTokenPayload(
            impressionId: impressionId,
            storeId: selected.id,
            festivalId: selected.festivalId,
            placement: placement,
            expiresAt: now.addingTimeInterval(120)
        )
        let token = try ImpressionToken().sign(payload)
        return AdCandidate(
            storeId: selected.id,
            festivalId: selected.festivalId,
            placement: placement,
            imagePath: imagePath,
            updatedAt: selected.updatedAt,
            impressionId: impressionId,
            impressionToken: token
        )
    }

    func report(_ request: AdvertisementReportRequest) async throws {
        let reason = request.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty, reason.count <= 1_000 else {
            throw Error.badRequest("通報理由は1〜1000文字で入力してください。")
        }
        guard let store = try await stores.find(id: request.storeId) else {
            throw Error.notFound("通報対象の店舗が見つかりません。")
        }
        try await notifications.notify(
            storeId: store.id,
            festivalId: store.festivalId,
            placement: request.placement,
            reason: reason,
            receivedAt: Date()
        )
    }
}
