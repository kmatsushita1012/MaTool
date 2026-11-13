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
}
