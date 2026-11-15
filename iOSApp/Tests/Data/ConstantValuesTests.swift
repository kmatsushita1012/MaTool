import Dependencies
import Testing
@testable import iOSApp

struct ConstantValuesTests {
    @Test("DependencyValuesの値を差し替えると全ての設定値を一貫して読み出せる")
    func injectedValuesAreReadThroughDependencyKey() {
        let actual = withDependencies {
            $0.values = .testFixture
        } operation: {
            @Dependency(\.values) var values
            return values
        }

        #expect(actual.apiBaseUrl.isEmpty)
        #expect(actual.appStatusUrl.isEmpty)
        #expect(actual.defaultFestivalKey == "region")
        #expect(actual.defaultDistrictKey == "district")
        #expect(actual.loginIdKey == "login")
        #expect(actual.hasLaunchedBeforeKey == "hasLaunchedBefore")
        #expect(actual.userGuideUrl.isEmpty)
        #expect(actual.contactURL.isEmpty)
        #expect(actual.isLiquidGlassEnabled == false)
        #expect(actual.admobAppId == nil)
        #expect(actual.publicMapInterstitialAdUnitId == nil)
        #expect(actual.publicMapBannerAdUnitId == nil)
    }

    @Test("独立した依存スコープでは設定URLと広告IDが混同されない")
    func separateScopesKeepDistinctSettings() {
        let first = withDependencies {
            $0.values = .testFixture
        } operation: {
            @Dependency(\.values) var values
            return values.apiBaseUrl
        }
        let configured = ConstantValues(
            apiBaseUrl: "https://api.example.com",
            appStatusUrl: "https://status.example.com",
            defaultFestivalKey: "festival",
            defaultDistrictKey: "district",
            loginIdKey: "login",
            hasLaunchedBeforeKey: "launch",
            userGuideUrl: "https://guide.example.com",
            contactURL: "https://contact.example.com",
            isLiquidGlassEnabled: true,
            admobAppId: "app-id",
            publicMapInterstitialAdUnitId: "interstitial-id",
            publicMapBannerAdUnitId: "banner-id",
            storeCreditProductId500: "credit-500",
            storeCreditProductId1000: "credit-1000"
        )
        let second = withDependencies {
            $0.values = configured
        } operation: {
            @Dependency(\.values) var values
            return values
        }

        #expect(first.isEmpty)
        #expect(second.apiBaseUrl == "https://api.example.com")
        #expect(second.appStatusUrl == "https://status.example.com")
        #expect(second.isLiquidGlassEnabled)
        #expect(second.admobAppId == "app-id")
        #expect(second.publicMapInterstitialAdUnitId == "interstitial-id")
        #expect(second.publicMapBannerAdUnitId == "banner-id")
        #expect(second.storeCreditProductId500 == "credit-500")
        #expect(second.storeCreditProductId1000 == "credit-1000")
    }
}
