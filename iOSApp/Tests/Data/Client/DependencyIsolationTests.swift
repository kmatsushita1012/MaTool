import Dependencies
import Testing
@testable import iOSApp

struct DependencyIsolationTests {
    @Test("テスト用の依存は実サービスに解決されない")
    func testDependenciesDoNotUseLiveClients() {
        withDependencies {
            $0.context = .test
        } operation: {
            @Dependency(MapLocationProviderKey.self) var mapLocation
            @Dependency(BroadcastLocationProviderKey.self) var broadcastLocation
            @Dependency(HTTPClientKey.self) var httpClient
            @Dependency(UserDefaltsManagerKey.self) var userDefaults
            @Dependency(ImageCacheClientKey.self) var imageCache
            @Dependency(AppStatusClientKey.self) var appStatus
            @Dependency(AdManagerKey.self) var adManager

            #expect(!(mapLocation is MapLocationProvider))
            #expect(!(broadcastLocation is BroadcastLocationProvider))
            #expect(!(httpClient is HTTPClient))
            #expect(!(userDefaults is UserDefaltsManager))
            #expect(!(imageCache is ImageCacheClient))
            #expect(!(appStatus is AppStatusClient))
            #expect(!(adManager is AdManager))
        }
    }
}
