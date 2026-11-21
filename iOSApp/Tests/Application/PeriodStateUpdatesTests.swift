import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import iOSApp

struct PeriodStateUpdatesTests {
    @Test("EditionPack応答を採用し、対象PeriodがないRouteと選択状態を除去する")
    func packUpdateRemovesOrphanRoutesAndSelection() {
        let old = AppStateFixture.period()
        let validRoute = AppStateFixture.route(id: "valid")
        let orphanRoute = AppStateFixture.route(id: "orphan", periodId: "missing")
        let appState = Shared<AppState?>(value: AppStateFixture.state(
            periods: [old], routes: [validRoute, orphanRoute], currentRouteId: orphanRoute.id
        ))
        let sessionId = appState.wrappedValue?.sessionId
        var response = old
        response.title = "server response"

        applyEditionPack(
            EditionPack(edition: AppStateFixture.edition(), periods: [response]),
            sessionId: sessionId,
            to: appState
        )

        #expect(appState.wrappedValue?.festivalState.periods == [response])
        #expect(appState.wrappedValue?.districtState?.routes == [validRoute])
        #expect(appState.wrappedValue?.routeState == nil)
    }

    @Test("保存後の空EditionPackは関連Routeと選択Routeも消去する")
    func emptyPackPrunesRoutesAndSelection() {
        let route = AppStateFixture.route()
        let appState = Shared<AppState?>(value: AppStateFixture.state(
            routes: [route], currentRouteId: route.id
        ))
        let sessionId = appState.wrappedValue?.sessionId

        applyEditionPack(
            EditionPack(edition: AppStateFixture.edition(), periods: []),
            sessionId: sessionId,
            to: appState
        )

        #expect(appState.wrappedValue?.festivalState.periods.isEmpty == true)
        #expect(appState.wrappedValue?.districtState?.routes.isEmpty == true)
        #expect(appState.wrappedValue?.routeState == nil)
    }

    @Test("nil・旧セッション・別Editionの応答は現在状態を書き換えない")
    func rejectsStaleAndUnrelatedPacks() {
        let original = AppStateFixture.state()
        let appState = Shared<AppState?>(value: original)
        let sameEdition = AppStateFixture.edition()
        let changedPeriod = AppStateFixture.period()
        let pack = EditionPack(edition: sameEdition, periods: [changedPeriod])

        applyEditionPack(pack, sessionId: nil, to: appState)
        #expect(appState.wrappedValue == original)

        applyEditionPack(pack, sessionId: UUID(), to: appState)
        #expect(appState.wrappedValue == original)

        let otherEdition = Edition(id: "other-edition", festivalId: "festival", year: 2025)
        applyEditionPack(EditionPack(edition: otherEdition, periods: []), sessionId: original.sessionId, to: appState)
        #expect(appState.wrappedValue == original)
    }

    @Test("nil AppStateはEditionPack応答で作成しない")
    func nilStateIsNotRecreated() {
        let appState = Shared<AppState?>(value: nil)
        applyEditionPack(
            EditionPack(edition: AppStateFixture.edition(), periods: [AppStateFixture.period()]),
            sessionId: UUID(),
            to: appState
        )
        #expect(appState.wrappedValue == nil)
    }

    @Test("EditionPackの追加期間を日時順に反映する")
    func packUpdateSortsPeriods() {
        let first = AppStateFixture.period(id: "first", day: 3)
        let earlier = AppStateFixture.period(id: "earlier", day: 1)
        let appState = Shared<AppState?>(value: AppStateFixture.state(periods: [first]))

        applyEditionPack(
            EditionPack(edition: AppStateFixture.edition(), periods: [first, earlier]),
            sessionId: appState.wrappedValue?.sessionId,
            to: appState
        )

        #expect(appState.wrappedValue?.festivalState.periods.map(\.id) == ["earlier", "first"])
    }
}
