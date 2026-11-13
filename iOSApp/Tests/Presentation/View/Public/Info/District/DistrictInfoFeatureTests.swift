import ComposableArchitecture
import MapKit
import Shared
import SwiftUI
import Testing
@testable import iOSApp

struct DistrictInfoFeatureTests {
    private func makeState() -> DistrictInfoFeature.State {
        let district = AppStateFixture.district()
        return DistrictInfoFeature.State(
            DistrictPack(district: district, performances: []),
            appState: Shared(value: AppStateFixture.state())
        )
    }

    @Test("初期状態は選択中地区を参照しテーマ未解決である")
    func initialStateUsesDistrict() {
        let state = makeState()
        #expect(state.districtId == "district")
        #expect(state.district.id == "district")
        #expect(state.appStateDistrict?.id == "district")
        #expect(state.performances.isEmpty)
        #expect(state.colorTheme == nil)
    }

    @Test("最初のテーマ解決だけを採用し再解決で上書きしない")
    @MainActor
    func resolvesThemeOnlyOnce() async {
        let store = TestStore(initialState: makeState()) {
            DistrictInfoFeature()
        }

        await store.send(.colorThemeResolved(.dark)) {
            $0.colorTheme = .dark
        }
        await store.send(.colorThemeResolved(.light))
        #expect(store.state.colorTheme == .dark)
        await store.finish()
    }

    @Test("ユーザーがテーマを選択すると既存テーマを上書きする")
    @MainActor
    func explicitThemeSelectionOverridesResolvedTheme() async {
        var state = makeState()
        state.colorTheme = .dark
        let store = TestStore(initialState: state) {
            DistrictInfoFeature()
        }

        await store.send(.colorThemeSelected(.light)) {
            $0.colorTheme = .light
        }
        await store.finish()
    }

    @Test("バインディングで選択したテーマは状態に反映される")
    @MainActor
    func bindingUpdatesTheme() async {
        let store = TestStore(initialState: makeState()) {
            DistrictInfoFeature()
        }

        await store.send(.binding(.set(\\.colorTheme, .dark))) {
            $0.colorTheme = .dark
        }
        await store.finish()
    }
    @Test("地区の範囲が空なら基点を中心とする地図領域を使用する")
    func regionUsesDistrictBaseWhenAreaIsEmpty() throws {
        let district = District(
            id: "district", name: "District", festivalId: "festival",
            base: Coordinate(latitude: 35.2, longitude: 139.4)
        )
        let state = DistrictInfoFeature.State(
            DistrictPack(district: district, performances: []),
            appState: Shared(value: AppStateFixture.state(districts: [district]))
        )
        let region = try #require(state.region)
        #expect(region.center.latitude == 35.2)
        #expect(region.center.longitude == 139.4)
        #expect(region.span.latitudeDelta == spanDelta)
    }

    @Test("地区の範囲が指定されていれば基点より範囲を優先する")
    func regionUsesAreaInsteadOfBase() throws {
        let district = District(
            id: "district", name: "District", festivalId: "festival",
            base: Coordinate(latitude: 30, longitude: 130),
            area: [
                Coordinate(latitude: 35, longitude: 139),
                Coordinate(latitude: 36, longitude: 141)
            ]
        )
        let state = DistrictInfoFeature.State(
            DistrictPack(district: district, performances: []),
            appState: Shared(value: AppStateFixture.state(districts: [district]))
        )
        let region = try #require(state.region)
        #expect(region.center.latitude == 35.5)
        #expect(region.center.longitude == 140)
    }

}
