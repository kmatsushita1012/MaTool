import CoreLocation
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct LocationUsecaseTests {
    @Test("LocationUsecaseは権限状態とUD managerの保存値を返す")
    func 権限状態と保存値を返す() async {
        let userDefaults = DefaultUserDefaultsSpy(
            hasRequestedAlwaysLocationPermission: true
        )
        let provider = BroadcastLocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
        let usecase = makeUsecase(provider: provider, userDefaults: userDefaults)

        let state = await usecase.locationPermissionState()

        #expect(state.authorizationStatus == .authorizedWhenInUse)
        #expect(state.hasRequestedAlwaysLocationPermission)
    }

    @Test("常に許可要求の通知を受けた時だけUD managerへ保存する")
    func 常に許可要求の通知時だけ保存する() async {
        let userDefaults = DefaultUserDefaultsSpy(
            hasRequestedAlwaysLocationPermission: false
        )
        let provider = BroadcastLocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
        let usecase = makeUsecase(provider: provider, userDefaults: userDefaults)

        await usecase.requestPermission()
        #expect(userDefaults.hasRequestedAlwaysLocationPermission == false)

        await provider.notifyAlwaysAuthorizationRequest()

        #expect(userDefaults.hasRequestedAlwaysLocationPermission)
    }

    @Test("配信開始前に常に許可を再確認し、未許可なら開始しない")
    func 配信開始前に常に許可を再確認する() async {
        let userDefaults = DefaultUserDefaultsSpy(
            hasRequestedAlwaysLocationPermission: false
        )
        let provider = BroadcastLocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
        let usecase = makeUsecase(provider: provider, userDefaults: userDefaults)

        let result = await usecase.start(id: "district-a", interval: .sample)

        #expect(
            result == .permissionRequired(
                LocationPermissionState(
                    authorizationStatus: .authorizedWhenInUse,
                    hasRequestedAlwaysLocationPermission: false
                )
            )
        )
        #expect(await provider.startTrackingCallCount == 0)
    }

    private func makeUsecase(
        provider: BroadcastLocationProviderSpy,
        userDefaults: UserDefaultsManagerSpy
    ) -> LocationUsecase {
        withDependencies {
            $0.installTestSpies()
            $0[BroadcastLocationProviderKey.self] = provider
            $0[UserDefaltsManagerKey.self] = userDefaults
        } operation: {
            LocationUsecase()
        }
    }
}
