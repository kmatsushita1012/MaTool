import ComposableArchitecture
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct SettingsFeatureTests {
    @Test("町Pickerはorderの昇順で並ぶ")
    func districtsAreSortedForPicker() {
        let festival = Festival(
            id: "festival",
            name: "Festival",
            subname: "Festival",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let firstDistrict = District(
            id: "group-b-first",
            name: "B一町",
            festivalId: festival.id,
            order: 0,
            group: "B"
        )
        let laterDistrict = District(
            id: "group-a-later",
            name: "A二町",
            festivalId: festival.id,
            order: 2,
            group: "A"
        )
        let middleDistrict = District(
            id: "group-a-first",
            name: "A一町",
            festivalId: festival.id,
            order: 1,
            group: "A"
        )
        let appState = Shared<AppState?>(value: AppState(
            festivalPack: LaunchFestivalPack(
                festival: festival,
                districts: [laterDistrict, firstDistrict, middleDistrict],
                periods: [],
                locations: [],
                checkpoints: [],
                hazardSections: []
            ),
            year: 2026
        ))

        let state = withDependencies {
            $0.values = ConstantValues(
                apiBaseUrl: "",
                appStatusUrl: "",
                defaultFestivalKey: "festival",
                defaultDistrictKey: "district",
                loginIdKey: "login",
                hasLaunchedBeforeKey: "launched",
                userGuideUrl: "https://example.com/guide",
                contactURL: "https://example.com/contact",
                isLiquidGlassEnabled: false,
                admobAppId: nil,
                publicMapInterstitialAdUnitId: nil,
                publicMapBannerAdUnitId: nil
            )
        } operation: {
            SettingsFeature.State(
                selection: SceneSelection(festivalId: festival.id, districtId: nil),
                festivals: [festival],
                appState: appState
            )
        }

        #expect(state.districts.map(\.id) == [firstDistrict.id, middleDistrict.id, laterDistrict.id])
    }
}
