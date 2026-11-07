import Dependencies
import Foundation
import Shared

enum ImpressionUsecaseKey: DependencyKey {
    static let liveValue: any ImpressionUsecaseProtocol = ImpressionUsecase()
}

protocol ImpressionUsecaseProtocol: Sendable {
    func report(_ request: ImpressionReportRequest) async throws
}

struct ImpressionUsecase: ImpressionUsecaseProtocol {
    @Dependency(StoreRepositoryKey.self) var stores
    @Dependency(ImpressionRepositoryKey.self) var impressions

    func report(_ request: ImpressionReportRequest) async throws {
        let payload = try ImpressionToken().verify(request.impressionToken)
        guard payload.impressionId == request.impressionId else { throw Error.badRequest("表示実績 token の対象が一致しません。") }
        guard let store = try await stores.get(id: payload.storeId, festivalId: payload.festivalId, consistentRead: true) else {
            throw Error.notFound("表示対象の店舗が見つかりません。")
        }
        let image = payload.placement == .banner ? store.bannerImagePath : store.interstitialImagePath
        guard store.moderationStatus == .approved,
              !store.ownerPaused,
              image != nil else {
            return
        }
        _ = try await impressions.charge(
            impressionId: payload.impressionId,
            storeId: store.id,
            placement: payload.placement,
            chargedAt: Date()
        )
    }
}
