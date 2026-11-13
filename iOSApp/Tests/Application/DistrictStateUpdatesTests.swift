import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import iOSApp

struct DistrictStateUpdatesTests {
    private func pack(
        routes: [Route] = [AppStateFixture.route()],
        selectedRoute: Route.ID? = "route"
    ) -> LaunchDistrictPack {
        LaunchDistrictPack(
            performances: [], routes: routes,
            points: [], passages: [], currentRouteId: selectedRoute
        )
    }

    @Test("地区データの再読込開始時に旧地区・ルート状態を無効化する")
    func startingLoadInvalidatesOldDistrictAndRoute() {
        let route = AppStateFixture.route()
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [route], currentRouteId: route.id
        ))
        let oldDistrictRequest = state.wrappedValue?.districtLoadRequestId
        let oldRouteRequest = state.wrappedValue?.routeLoadRequestId

        let context = beginDistrictStateLoad(in: state)

        #expect(context.sessionId == state.wrappedValue?.sessionId)
        #expect(context.requestId == state.wrappedValue?.districtLoadRequestId)
        #expect(context.requestId != oldDistrictRequest)
        #expect(state.wrappedValue?.routeLoadRequestId != oldRouteRequest)
        #expect(state.wrappedValue?.districtState == nil)
        #expect(state.wrappedValue?.routeState == nil)
    }

    @Test("最新の地区読込レスポンスから地区と選択中のルートを復元する")
    func matchingResponseRebuildsDistrictState() {
        let route = AppStateFixture.route()
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let context = beginDistrictStateLoad(in: state)

        let applied = applyDistrictStateResponse(
            pack(routes: [route]), districtId: "district", context: context, to: state
        )

        #expect(applied)
        #expect(state.wrappedValue?.districtState?.districtId == "district")
        #expect(state.wrappedValue?.districtState?.requestId == context.requestId)
        #expect(state.wrappedValue?.routeState?.route == route)
    }

    @Test("選択中のルートがレスポンスにない場合はRouteStateを作らない")
    func absentSelectedRouteIsNotFabricated() {
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let context = beginDistrictStateLoad(in: state)

        #expect(applyDistrictStateResponse(
            pack(routes: [], selectedRoute: "missing"),
            districtId: "district", context: context, to: state
        ))
        #expect(state.wrappedValue?.districtState?.routes.isEmpty == true)
        #expect(state.wrappedValue?.routeState == nil)
    }

    @Test("旧リクエストが遅れて成功しても新しい状態は変更しない")
    func rejectsStaleRequestID() {
        let original = AppStateFixture.state()
        let state = Shared<AppState?>(value: original)
        let staleContext = beginDistrictStateLoad(in: state)
        let currentContext = beginDistrictStateLoad(in: state)
        let before = state.wrappedValue

        #expect(staleContext.requestId != currentContext.requestId)
        #expect(!applyDistrictStateResponse(
            pack(), districtId: "district", context: staleContext, to: state
        ))
        #expect(state.wrappedValue == before)
    }

    @Test("別セッション・存在しない地区からのレスポンスを無視する")
    func rejectsForeignSessionAndUnknownDistrict() {
        let state = Shared<AppState?>(value: AppStateFixture.state())
        let context = beginDistrictStateLoad(in: state)
        let before = state.wrappedValue

        #expect(!applyDistrictStateResponse(
            pack(), districtId: "unknown", context: context, to: state
        ))
        #expect(!applyDistrictStateResponse(
            pack(), districtId: "district",
            context: DistrictStateLoadContext(
                requestId: context.requestId, sessionId: UUID()
            ), to: state
        ))
        #expect(state.wrappedValue == before)
    }

    @Test("状態がnilのときはロード開始でも状態を新規作成しない")
    func nilStateRemainsNil() {
        let state = Shared<AppState?>(value: nil)
        let context = beginDistrictStateLoad(in: state)

        #expect(context.sessionId == nil)
        #expect(!applyDistrictStateResponse(
            pack(), districtId: "district", context: context, to: state
        ))
        clearDistrictState(in: state)
        #expect(state.wrappedValue == nil)
    }

    @Test("地区選択の解除では新旧のリクエストを無効化する")
    func clearingDistrictInvalidatesOldRequests() {
        let route = AppStateFixture.route()
        let state = Shared<AppState?>(value: AppStateFixture.state(
            routes: [route], currentRouteId: route.id
        ))
        let firstRequest = state.wrappedValue?.districtLoadRequestId
        let firstRouteRequest = state.wrappedValue?.routeLoadRequestId

        clearDistrictState(in: state)

        #expect(state.wrappedValue?.districtState == nil)
        #expect(state.wrappedValue?.routeState == nil)
        #expect(state.wrappedValue?.districtLoadRequestId != firstRequest)
        #expect(state.wrappedValue?.routeLoadRequestId != firstRouteRequest)
    }
}
