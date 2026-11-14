import Testing
@testable import iOSApp

struct LocationErrorTests {
    @Test("常時位置情報権限が拒否された場合の説明はアクセス権限を示す")
    func deniedAuthorizationHasRelevantMessage() {
        #expect(LocationError.authorizationDenied.errorDescription == "位置情報の常に許可がありません。")
    }

    @Test("位置情報サービスが無効な場合の説明は端末設定を示す")
    func disabledServicesHasRelevantMessage() {
        #expect(LocationError.servicesDisabled.errorDescription == "位置情報サービスが無効です。")
    }
}
