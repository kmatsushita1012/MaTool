import Foundation
import Shared
import Testing
@testable import iOSApp

struct StatusTextTests {
    @Test("DEBUGでは位置情報取得失敗の詳細を履歴に表示する")
    func DEBUGでは位置情報取得失敗の詳細を履歴に表示する() {
#if DEBUG
        let status = Status.locationError(Date(timeIntervalSince1970: 0), "詳細な取得エラー")

        #expect(status.text.contains("取得失敗"))
        #expect(status.text.contains("\n詳細な取得エラー"))
#endif
    }

}
