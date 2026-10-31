import Dependencies
import Testing
@testable import iOSApp

struct DependencyIsolationTests {
    @Test("テスト用の依存はTests/UtilityのSpyを使う")
    func resolvesInjectedSpies() async {
        let mapSpy = MapLocationProviderSpy()
        let dependencies = withDependencies {
            $0.installTestSpies()
            $0[MapLocationProviderKey.self] = mapSpy
        } operation: {
            @Dependency(MapLocationProviderKey.self) var mapLocation
            @Dependency(BroadcastLocationProviderKey.self) var broadcastLocation
            @Dependency(HTTPClientKey.self) var httpClient
            @Dependency(UserDefaltsManagerKey.self) var userDefaults
            @Dependency(ImageCacheClientKey.self) var imageCache
            @Dependency(AppStatusClientKey.self) var appStatus
            @Dependency(AdManagerKey.self) var adManager
            return (mapLocation, broadcastLocation, httpClient, userDefaults, imageCache, appStatus, adManager)
        }

        #expect(dependencies.0 is MapLocationProviderSpy)
        #expect(dependencies.1 is BroadcastLocationProviderSpy)
        #expect(dependencies.2 is HTTPClientSpy)
        #expect(dependencies.3 is DefaultUserDefaultsSpy)
        #expect(dependencies.4 is ImageCacheClientSpy)
        #expect(dependencies.5 is AppStatusClientSpy)
        #expect(dependencies.6 is AdManagerSpy)

        await dependencies.0.requestPermission()
        #expect(await mapSpy.permissionRequests == 1)
    }
}
