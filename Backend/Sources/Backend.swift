//
//  Backend.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

@main
struct MaToolAPI: APIGateway {
    static let app = Application{
        AuthMiddleware(path: "/")
        ImageRouter()
        StoreRouter()
        PurchaseRouter()
        AdvertisementRouter()
        FestivalRouter()
        DistrictRouter()
        OtherRouter()
    }

    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == "recover-app-store-notifications" {
            guard arguments.count == 3 else {
                throw Error.badRequest("使い方: recover-app-store-notifications <開始日時UTC> <終了日時UTC>")
            }
            let recovered = try await AppStoreNotificationHistoryRecovery().run(
                startDate: arguments[1],
                endDate: arguments[2]
            )
            print("Apple 通知履歴から \(recovered) 件を再処理しました。")
            return
        }
        try await runLambda()
    }
}
