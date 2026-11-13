import ComposableArchitecture
import Testing
@testable import iOSApp

struct AlertFeatureTests {
    @Test("エラー・成功・通知では指定されたタイトルと本文を保持する")
    func buildsInformationAlerts() {
        let error = AlertFeature.error("接続できません")
        #expect(error.title == TextState("エラー"))
        #expect(error.message == TextState("接続できません"))

        let success = AlertFeature.success("保存しました", title: "保存成功")
        #expect(success.title == TextState("保存成功"))
        #expect(success.message == TextState("保存しました"))

        let notice = AlertFeature.notice("開催予定", title: "案内")
        #expect(notice.title == TextState("案内"))
        #expect(notice.message == TextState("開催予定"))
    }

    @Test("削除確認の既定とカスタム本文を保持する")
    func buildsDeleteConfirmation() {
        let defaultAlert = AlertFeature.delete()
        #expect(defaultAlert.title == TextState("確認"))
        #expect(defaultAlert.message == TextState("このデータを削除してもよろしいですか？この操作は元に戻せません。"))

        let customAlert = AlertFeature.delete("削除しますか", title: "操作確認")
        #expect(customAlert.title == TextState("操作確認"))
        #expect(customAlert.message == TextState("削除しますか"))
    }

    @Test("参加設定変更確認は内容を伝え、操作が可能である")
    func buildsParticipationChangeConfirmation() {
        let alert = AlertFeature.participationChangeConfirmation()
        #expect(alert.title == TextState("参加設定を変更"))
        #expect(alert.message == TextState("参加設定を変更すると、管理者アカウントからサインアウトします。続けますか？"))
    }

    @Test("AlertReducerはタップ通知のみで状態を勝手に変更しない")
    @MainActor
    func reducerDoesNotMutateAlertUnexpectedly() async {
        let alert = AlertFeature.error("message")
        let store = TestStore(initialState: alert) {
            AlertFeature()
        }
        await store.send(.okTapped)
        await store.finish()
    }

    @Test("AlertState拡張はAppErrorのメッセージも表示する")
    func errorFromAppError() {
        let error = AppError.be(.network("offline"))
        let alert: AlertFeature.State = .error(error)
        #expect(alert.title == TextState("エラー"))
        #expect(alert.message == TextState(error.message))
    }
}
