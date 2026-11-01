import AWSSNS
import Dependencies
import Foundation
import Shared

enum ReportNotificationClientKey: DependencyKey {
    static let liveValue: any ReportNotificationClientProtocol = ReportNotificationClient()
}

extension DependencyValues {
    var reportNotificationClient: any ReportNotificationClientProtocol {
        get { self[ReportNotificationClientKey.self] }
        set { self[ReportNotificationClientKey.self] = newValue }
    }
}

protocol ReportNotificationClientProtocol: Sendable {
    func notify(storeId: Store.ID, festivalId: Festival.ID, placement: StoreAdPlacement?, reason: String, receivedAt: Date) async throws
}

struct ReportNotificationClient: ReportNotificationClientProtocol {
    func notify(storeId: Store.ID, festivalId: Festival.ID, placement: StoreAdPlacement?, reason: String, receivedAt: Date) async throws {
        let topicARN = AdvertisingEnvironment().reportTopicARN
        guard !topicARN.isEmpty else { throw Error.internalServerError("広告通報の通知先が設定されていません。") }
        struct Message: Encodable {
            let storeId: String
            let festivalId: String
            let placement: StoreAdPlacement?
            let reason: String
            let receivedAt: Date
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Message(storeId: storeId, festivalId: festivalId, placement: placement, reason: reason, receivedAt: receivedAt))
        guard let message = String(data: data, encoding: .utf8) else { throw Error.internalServerError("広告通報をエンコードできませんでした。") }
        let client = try await SNSClient()
        _ = try await client.publish(input: .init(message: message, topicArn: topicARN))
    }
}
