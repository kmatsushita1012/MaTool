import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import iOSApp

struct PeriodStateUpdatesTests {
    @Test("同一セッションの更新はレスポンスだけを採用し、存在しない期間のルートを除去する")
    func updateRemovesOrphanRoutesAndSelection() {
        let old = AppStateFixture.period()
        let validRoute = AppStateFixture.route(id: "valid")
        let orphanRoute = AppStateFixture.route(id: "orphan", periodId: "missing")
        let appState = Shared<AppState?>(value: AppStateFixture.state(
            periods: [old], routes: [validRoute, orphanRoute], currentRouteId: orphanRoute.id
        ))
        let sessionId = appState.wrappedValue?.sessionId
        var response = old
        response.title = "server response"

        applyPeriodResponse(response, sessionId: sessionId, to: appState)

        #expect(appState.wrappedValue?.festivalState.periods.first?.title == "server response")
        #expect(appState.wrappedValue?.districtState?.routes == [validRoute])
        #expect(appState.wrappedValue?.routeState == nil)
    }

    @Test("期間削除は関連ルートと選択中のルートを一緒に無効化する")
    func deletePrunesSelectedRoute() {
        let route = AppStateFixture.route()
        let appState = Shared<AppState?>(value: AppStateFixture.state(
            routes: [route], currentRouteId: route.id
        ))
        let sessionId = appState.wrappedValue?.sessionId

        removePeriod("period", sessionId: sessionId, from: appState)

        #expect(appState.wrappedValue?.festivalState.periods.isEmpty == true)
        #expect(appState.wrappedValue?.districtState?.routes.isEmpty == true)
        #expect(appState.wrappedValue?.routeState == nil)
    }

    @Test("nil・旧セッション・異なる祭典のレスポンスは現在の状態を書き換えない")
    func updateRejectsStaleAndUnrelatedResponses() {
        let original = AppStateFixture.state()
        let appState = Shared<AppState?>(value: original)
        var changed = AppStateFixture.period()
        changed.title = "stale"

        applyPeriodResponse(changed, sessionId: nil, to: appState)
        #expect(appState.wrappedValue == original)

        applyPeriodResponse(changed, sessionId: UUID(), to: appState)
        #expect(appState.wrappedValue == original)

        let otherFestival = Period(
            id: changed.id, festivalId: "another-festival", title: changed.title,
            date: changed.date, start: changed.start, end: changed.end
        )
        applyPeriodResponse(otherFestival, sessionId: original.sessionId, to: appState)
        #expect(appState.wrappedValue == original)
    }

    @Test("nil・旧セッションでの期間削除は安全に無視する")
    func deleteRejectsStaleSession() {
        let original = AppStateFixture.state()
        let appState = Shared<AppState?>(value: original)

        removePeriod("period", sessionId: nil, from: appState)
        #expect(appState.wrappedValue == original)

        removePeriod("period", sessionId: UUID(), from: appState)
        #expect(appState.wrappedValue == original)
    }

    @Test("空の状態に対する更新・削除は値を作成しない")
    func updatesDoNotRecreateNilSession() {
        let appState = Shared<AppState?>(value: nil)
        applyPeriodResponse(AppStateFixture.period(), sessionId: UUID(), to: appState)
        removePeriod("period", sessionId: UUID(), from: appState)
        #expect(appState.wrappedValue == nil)
    }

    @Test("新しい期間を追加する場合は既存の期間を維持して日時順に並べる")
    func insertPeriodSortsServerResponse() {
        let first = AppStateFixture.period(id: "first", day: 3)
        let newPeriod = AppStateFixture.period(id: "earlier", day: 1)
        let appState = Shared<AppState?>(value: AppStateFixture.state(periods: [first]))

        applyPeriodResponse(newPeriod, sessionId: appState.wrappedValue?.sessionId, to: appState)

        #expect(appState.wrappedValue?.festivalState.periods.map(\.id) == ["earlier", "first"])
    }
}
