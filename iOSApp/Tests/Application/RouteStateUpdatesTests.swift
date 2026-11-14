import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import iOSApp

struct RouteStateUpdatesTests {
    @Test("同じセッションと地区に対してはAPIレスポンスのルートを反映する")
    func updatesCurrentRoute() {
        let original = AppStateFixture.route(description: "local")
        let response = AppStateFixture.route(description: "server")
        let state = Shared<AppState?>(value: AppStateFixture.state(routes: [original]))
        let context = captureRouteStateUpdateContext(state)
        let oldRequestId = state.wrappedValue?.routeLoadRequestId

        applyRoutePackResponse(
            RoutePack(route: response, points: [], passages: []),
            context: context, to: state
        )

        #expect(state.wrappedValue?.districtState?.routes.map(\.description) == ["server"])
        #expect(state.wrappedValue?.routeState?.route == response)
        #expect(state.wrappedValue?.routeLoadRequestId != oldRequestId)
    }

    @Test("存在しない期間への更新レスポンスはローカルルートを削除する")
    func removesRouteWhenPeriodDisappears() {
        let obsolete = AppStateFixture.route(periodId: "deleted")
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [obsolete], currentRouteId: obsolete.id
        ))
        let context = captureRouteStateUpdateContext(state)

        applyRoutePackResponse(
            RoutePack(route: obsolete, points: [], passages: []),
            context: context, to: state
        )

        #expect(state.wrappedValue?.districtState?.routes.isEmpty == true)
        #expect(state.wrappedValue?.routeState == nil)
    }

    @Test("古いセッションと古い地区ロード要求は反映しない")
    func rejectsOutdatedStateContext() {
        let route = AppStateFixture.route()
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let oldContext = captureRouteStateUpdateContext(state)
        let pack = RoutePack(route: route, points: [], passages: [])

        state.withLock { current in
            guard var updated = current else { return }
            updated.districtState = DistrictState(
                districtId: "district", requestId: UUID(),
                pack: LaunchDistrictPack(
                    performances: [], routes: [], points: [],
                    passages: [], currentRouteId: nil
                )
            )
            current = updated
        }
        let afterSwitch = state.wrappedValue
        applyRoutePackResponse(pack, context: oldContext, to: state)
        #expect(state.wrappedValue == afterSwitch)

        applyRoutePackResponse(
            pack, context: RouteStateUpdateContext(
                sessionId: UUID(), districtRequestId: state.wrappedValue?.districtState?.requestId
            ), to: state
        )
        #expect(state.wrappedValue == afterSwitch)
    }

    @Test("nilセッションと別地区のルートはローカル状態を更新しない")
    func rejectsNoSessionOrWrongDistrict() {
        let route = AppStateFixture.route(districtId: "another")
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let pack = RoutePack(route: route, points: [], passages: [])

        applyRoutePackResponse(
            pack, context: RouteStateUpdateContext(
                sessionId: nil,
                districtRequestId: original.districtState?.requestId
            ), to: state
        )
        #expect(state.wrappedValue == original)

        applyRoutePackResponse(
            pack, context: captureRouteStateUpdateContext(state), to: state
        )
        #expect(state.wrappedValue == original)
    }
}
