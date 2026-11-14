import Foundation
import Testing
@testable import iOSApp

struct AppStatusClientTests {
    private func statusJSON(
        requiredVersion: String,
        maintenanceUntil: Date? = nil
    ) -> String {
        let maintenance: String
        if let maintenanceUntil {
            let until = ISO8601DateFormatter().string(from: maintenanceUntil)
            maintenance = #""maintenance":{"message":"一時停止","until":""# + until + #""},"#
        } else {
            maintenance = ""
        }
        return "{" + maintenance +
            #""update":{"ios":{"requiredVersion":""# + requiredVersion +
            #"","storeUrl":"https://apps.apple.com/app/id123"}}}"#
    }

    @Test("必須バージョンに達している場合はアップデート不要")
    func currentVersionIsAccepted() async {
        let url = AppStatusURLProtocolSpy.makeURL(json: statusJSON(requiredVersion: "2.0.0"))
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "2.0.0") == nil)
        #expect(await client.checkStatus(currentVersion: "3.0.0") == nil)
    }

    @Test("最低必須バージョンより古い場合はStore URLを返す")
    func outdatedVersionRequiresUpdate() async {
        let url = AppStatusURLProtocolSpy.makeURL(json: statusJSON(requiredVersion: "3.0.0"))
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "2.9.9") ==
                .updateRequired(storeURL: URL(string: "https://apps.apple.com/app/id123")!))
    }

    @Test("メンテナンス期間中はバージョン判定より先に停止を通知する")
    func maintenanceTakesPrecedence() async {
        let until = Date().addingTimeInterval(3600)
        let url = AppStatusURLProtocolSpy.makeURL(
            json: statusJSON(requiredVersion: "9.0.0", maintenanceUntil: until)
        )
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        let result = await client.checkStatus(currentVersion: "1.0.0")

        if case .maintenance(let message, let date) = result {
            #expect(message == "一時停止")
            #expect(abs(date.timeIntervalSince(until)) < 1)
        } else {
            Issue.record("メンテナンス期間中の状態が返りませんでした")
        }
    }

    @Test("期限切れのメンテナンスは無視して更新要否を判定する")
    func expiredMaintenanceDoesNotBlockApp() async {
        let until = Date().addingTimeInterval(-3600)
        let url = AppStatusURLProtocolSpy.makeURL(
            json: statusJSON(requiredVersion: "3.0.0", maintenanceUntil: until)
        )
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "2.0.0") ==
                .updateRequired(storeURL: URL(string: "https://apps.apple.com/app/id123")!))
    }

    @Test("サーバーの500エラーでは状態を捏造せずnilを返す")
    func rejectsNonSuccessStatus() async {
        let url = AppStatusURLProtocolSpy.makeURL(
            json: statusJSON(requiredVersion: "9.0.0"), status: 503
        )
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "1.0.0") == nil)
    }

    @Test("不正JSONではUpdate/メンテナンス状態を捏造しない")
    func invalidJSONReturnsNil() async {
        let url = AppStatusURLProtocolSpy.makeURL(json: #"{"update":{"ios":"invalid"}}"#)
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "1.0.0") == nil)
    }

    @Test("不正URLが指定された場合でもクラッシュしない")
    func invalidURLReturnsNil() async {
        let client = AppStatusClient(
            urlString: "%%%not a URL",
            session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "1.0.0") == nil)
    }

    @Test("キャッシュ済み設定があれば通信をせず同じ判定を返す")
    func cachedStatusWorksWithoutNetwork() async {
        let status = AppStatus(
            maintenance: nil,
            update: Update(
                ios: UpdateInfo(
                    requiredVersion: "2.0.0",
                    storeUrl: URL(string: "https://apps.apple.com/app/id123")!
                ),
                android: nil
            )
        )
        let client = AppStatusClient(
            urlString: "invalid",
            session: AppStatusURLProtocolSpy.makeSession(),
            cachedStatus: status
        )

        #expect(await client.checkStatus(currentVersion: "1.0.0") ==
                .updateRequired(storeURL: URL(string: "https://apps.apple.com/app/id123")!))
    }

    @Test("引数省略のcheckStatusはアプリの現在バージョンを使用する")
    func usesCurrentApplicationVersion() async {
        let currentVersion = AppStatusClient.getCurrentVersion()
        #expect(!currentVersion.isEmpty)
        let status = AppStatus(
            maintenance: nil,
            update: Update(ios: UpdateInfo(
                requiredVersion: currentVersion,
                storeUrl: URL(string: "https://apps.apple.com/app/id123")!
            ), android: nil)
        )
        let client = AppStatusClient(
            urlString: "invalid",
            session: AppStatusURLProtocolSpy.makeSession(),
            cachedStatus: status
        )

        #expect(await client.checkStatus() == nil)
    }
    @Test("必須バージョンの各桁を数値比較し、境界直前のみ更新を要求する")
    func comparesVersionComponentsNumerically() async {
        let url = AppStatusURLProtocolSpy.makeURL(json: statusJSON(requiredVersion: "2.10.0"))
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "2.9.99") ==
                .updateRequired(storeURL: URL(string: "https://apps.apple.com/app/id123")!))
        #expect(await client.checkStatus(currentVersion: "2.10.0") == nil)
        #expect(await client.checkStatus(currentVersion: "2.11.0") == nil)
    }

    @Test("正常なHTTP応答でも日付の形式が不正ならメンテナンス情報を採用しない")
    func invalidMaintenanceDateReturnsNil() async {
        let json = #"{"maintenance":{"message":"停止","until":"not-a-date"},"update":{"ios":{"requiredVersion":"9.0.0","storeUrl":"https://apps.apple.com/app/id123"}}}"#
        let url = AppStatusURLProtocolSpy.makeURL(json: json)
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "1.0.0") == nil)
    }

    @Test("HTTP 204ではJSONが存在しないため更新要求を返さない")
    func emptySuccessfulResponseReturnsNil() async {
        let url = AppStatusURLProtocolSpy.makeURL(json: "", status: 204)
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "1.0.0") == nil)
    }

    @Test("キャッシュされたメンテナンス情報は通信なしで更新要求より優先される")
    func cachedMaintenancePrecedesRequiredUpdate() async {
        let until = Date().addingTimeInterval(3600)
        let status = AppStatus(
            maintenance: Maintenance(message: "緊急メンテナンス", until: until),
            update: Update(
                ios: UpdateInfo(
                    requiredVersion: "99.0.0",
                    storeUrl: URL(string: "https://apps.apple.com/app/id123")!
                ),
                android: nil
            )
        )
        let client = AppStatusClient(
            urlString: "invalid",
            session: AppStatusURLProtocolSpy.makeSession(),
            cachedStatus: status
        )

        let result = await client.checkStatus(currentVersion: "1.0.0")
        if case .maintenance(let message, let actualUntil) = result {
            #expect(message == "緊急メンテナンス")
            #expect(actualUntil == until)
        } else {
            Issue.record("キャッシュ済みメンテナンスが優先されませんでした")
        }
    }

    @Test("キャッシュされた期限切れメンテナンスは更新不要の判定を妨げない")
    func expiredCachedMaintenanceAllowsCurrentVersion() async {
        let status = AppStatus(
            maintenance: Maintenance(
                message: "終了したメンテナンス",
                until: Date().addingTimeInterval(-3600)
            ),
            update: Update(
                ios: UpdateInfo(
                    requiredVersion: "1.0.0",
                    storeUrl: URL(string: "https://apps.apple.com/app/id123")!
                ),
                android: nil
            )
        )
        let client = AppStatusClient(
            urlString: "invalid",
            session: AppStatusURLProtocolSpy.makeSession(),
            cachedStatus: status
        )
        #expect(await client.checkStatus(currentVersion: "1.0.0") == nil)
    }

    @Test("HTTP 201の成功レスポンスも正常な設定として扱う")
    func acceptsCreatedHTTPResponse() async {
        let url = AppStatusURLProtocolSpy.makeURL(
            json: statusJSON(requiredVersion: "3.0.0"), status: 201
        )
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "2.0.0") ==
                .updateRequired(storeURL: URL(string: "https://apps.apple.com/app/id123")!))
    }

    @Test("HTTP 300は成功扱いせず更新要求を返さない")
    func rejectsHTTP300Boundary() async {
        let url = AppStatusURLProtocolSpy.makeURL(
            json: statusJSON(requiredVersion: "3.0.0"), status: 300
        )
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "2.0.0") == nil)
    }


    @Test("HTTP 299は成功範囲の上限として設定を受け入れる")
    func acceptsHTTP299Boundary() async {
        let url = AppStatusURLProtocolSpy.makeURL(
            json: statusJSON(requiredVersion: "3.0.0"), status: 299
        )
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "2.0.0") ==
                .updateRequired(storeURL: URL(string: "https://apps.apple.com/app/id123")!))
    }

    @Test("HTTP 199は成功範囲外として設定を拒否する")
    func rejectsHTTP199Boundary() async {
        let url = AppStatusURLProtocolSpy.makeURL(
            json: statusJSON(requiredVersion: "3.0.0"), status: 199
        )
        let client = AppStatusClient(
            urlString: url.absoluteString, session: AppStatusURLProtocolSpy.makeSession()
        )

        #expect(await client.checkStatus(currentVersion: "2.0.0") == nil)
    }

    @Test("初回取得に成功した設定はセッション無効化後も再利用できる")
    func successfulFetchIsCachedForSubsequentChecks() async {
        let session = AppStatusURLProtocolSpy.makeSession()
        let url = AppStatusURLProtocolSpy.makeURL(json: statusJSON(requiredVersion: "4.0.0"))
        let client = AppStatusClient(urlString: url.absoluteString, session: session)

        #expect(await client.checkStatus(currentVersion: "3.0.0") ==
                .updateRequired(storeURL: URL(string: "https://apps.apple.com/app/id123")!))
        session.invalidateAndCancel()
        #expect(await client.checkStatus(currentVersion: "4.0.0") == nil)
        #expect(await client.checkStatus(currentVersion: "3.0.0") ==
                .updateRequired(storeURL: URL(string: "https://apps.apple.com/app/id123")!))
    }

}
