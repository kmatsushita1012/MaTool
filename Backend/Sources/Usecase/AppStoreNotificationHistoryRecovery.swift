import AppStoreServerLibrary
import Dependencies
import Foundation

enum AppStoreNotificationHistoryClientKey: DependencyKey {
    static let liveValue: any AppStoreNotificationHistoryClientProtocol = AppStoreNotificationHistoryClient()
}

extension DependencyValues {
    var appStoreNotificationHistoryClient: any AppStoreNotificationHistoryClientProtocol {
        get { self[AppStoreNotificationHistoryClientKey.self] }
        set { self[AppStoreNotificationHistoryClientKey.self] = newValue }
    }
}

protocol AppStoreNotificationHistoryClientProtocol: Sendable {
    func failedNotifications(startDate: Date, endDate: Date) async throws -> [String]
}

struct AppStoreNotificationHistoryClient: AppStoreNotificationHistoryClientProtocol {
    @Dependency(\.advertisingEnvironment) private var advertisingEnvironment

    func failedNotifications(startDate: Date, endDate: Date) async throws -> [String] {
        let client = try makeAppStoreServerAPIClient(environment: advertisingEnvironment.appStoreEnvironment, config: advertisingEnvironment)
        let request = NotificationHistoryRequest(startDate: startDate, endDate: endDate, onlyFailures: true)
        var paginationToken: String?
        var payloads: [String] = []

        repeat {
            let result = await client.getNotificationHistory(
                paginationToken: paginationToken,
                notificationHistoryRequest: request
            )
            let page: NotificationHistoryResponse
            switch result {
            case .success(let response): page = response
            case .failure(_, _, _, let message, _):
                throw Error.internalServerError("Apple 通知履歴を取得できませんでした: \(message ?? "unknown error")")
            }
            payloads.append(contentsOf: (page.notificationHistory ?? []).compactMap(\.signedPayload))
            if page.hasMore == true {
                guard let nextToken = page.paginationToken, !nextToken.isEmpty else {
                    throw Error.internalServerError("Apple 通知履歴のページ token がありません。")
                }
                paginationToken = nextToken
            } else {
                paginationToken = nil
            }
        } while paginationToken != nil

        return payloads
    }
}

struct AppStoreNotificationHistoryRecovery: Sendable {
    @Dependency(\.advertisingEnvironment) private var advertisingEnvironment
    @Dependency(\.appStoreNotificationHistoryClient) private var historyClient

    func run(startDate startText: String, endDate endText: String) async throws -> Int {
        guard let startDate = Self.parse(startText),
              let endDate = Self.parse(endText),
              startDate < endDate,
              startDate >= Date().addingTimeInterval(-180 * 24 * 60 * 60),
              endDate <= Date() else {
            throw Error.badRequest("開始・終了日時はUTC ISO 8601形式で指定し、過去180日以内の期間にしてください。")
        }

        let payloads = try await historyClient.failedNotifications(startDate: startDate, endDate: endDate)
        for payload in payloads {
            try await PurchaseUsecase().applyNotification(signedPayload: payload)
        }
        return payloads.count
    }

    private static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
