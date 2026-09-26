import CoreLocation
import Dependencies
import Shared
import Testing
@testable import iOSApp

struct LocationUsecaseTests {
    @Test("LocationUsecaseは権限状態とUD managerの保存値を返す")
    func 権限状態と保存値を返す() async {
        let userDefaults = UserDefaultsManagerSpy(
            hasRequestedAlwaysLocationPermission: true
        )
        let provider = LocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
        let usecase = makeUsecase(provider: provider, userDefaults: userDefaults)

        let state = await usecase.locationPermissionState()

        #expect(state.authorizationStatus == .authorizedWhenInUse)
        #expect(state.hasRequestedAlwaysLocationPermission)
    }

    @Test("常に許可要求の通知を受けた時だけUD managerへ保存する")
    func 常に許可要求の通知時だけ保存する() async {
        let userDefaults = UserDefaultsManagerSpy(
            hasRequestedAlwaysLocationPermission: false
        )
        let provider = LocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
        let usecase = makeUsecase(provider: provider, userDefaults: userDefaults)

        await usecase.requestPermission()
        #expect(userDefaults.hasRequestedAlwaysLocationPermission == false)

        await provider.notifyAlwaysAuthorizationRequest()

        #expect(userDefaults.hasRequestedAlwaysLocationPermission)
    }

    @Test("配信開始前に常に許可を再確認し、未許可なら開始しない")
    func 配信開始前に常に許可を再確認する() async {
        let userDefaults = UserDefaultsManagerSpy(
            hasRequestedAlwaysLocationPermission: false
        )
        let provider = LocationProviderSpy(authorizationStatus: .authorizedWhenInUse)
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

    @Test("DEBUGでは位置情報取得失敗の詳細を履歴に表示する")
    func DEBUGでは位置情報取得失敗の詳細を履歴に表示する() {
#if DEBUG
        let status = Status.locationError(Date(timeIntervalSince1970: 0), "詳細な取得エラー")

        #expect(status.text.contains("取得失敗"))
        #expect(status.text.contains("\n詳細な取得エラー"))
#endif
    }

    private func makeUsecase(
        provider: LocationProviderSpy,
        userDefaults: UserDefaultsManagerSpy
    ) -> LocationUsecase {
        withDependencies {
            $0[BroadcastLocationProviderKey.self] = provider
            $0[UserDefaltsManagerKey.self] = userDefaults
        } operation: {
            LocationUsecase()
        }
    }
}

private actor LocationProviderSpy: BroadcastLocationProviderProtocol {
    private let authorizationStatusValue: CLAuthorizationStatus
    private var onAlwaysAuthorizationRequest: (@Sendable () async -> Void)?
    private(set) var startTrackingCallCount = 0

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatusValue = authorizationStatus
    }

    func requestPermission(
        onAlwaysAuthorizationRequest: @escaping @Sendable () async -> Void
    ) async {
        self.onAlwaysAuthorizationRequest = onAlwaysAuthorizationRequest
    }

    func notifyAlwaysAuthorizationRequest() async {
        await onAlwaysAuthorizationRequest?()
    }

    func authorizationStatus() async -> CLAuthorizationStatus {
        authorizationStatusValue
    }

    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async {
        startTrackingCallCount += 1
    }

    func stopTracking() async {}

    func getLocation() async -> AsyncValue<CLLocation> {
        .loading
    }

    func isAlwaysAuthorized() async -> Bool {
        authorizationStatusValue == .authorizedAlways
    }

    func isLocationServicesEnabled() async -> Bool {
        true
    }

    var isTracking: Bool {
        get async { false }
    }
}

private final class UserDefaultsManagerSpy: UserDefalutsManagerProtocol, @unchecked Sendable {
    var defaultFestivalId: String?
    var defaultDistrictId: String?
    var hasRequestedAlwaysLocationPermission: Bool

    init(hasRequestedAlwaysLocationPermission: Bool) {
        self.hasRequestedAlwaysLocationPermission = hasRequestedAlwaysLocationPermission
    }

    func setHasRequestedAlwaysLocationPermission(_ value: Bool) {
        hasRequestedAlwaysLocationPermission = value
    }
}
