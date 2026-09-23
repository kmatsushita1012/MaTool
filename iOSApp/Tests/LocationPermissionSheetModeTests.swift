import CoreLocation
import Testing
@testable import iOSApp

struct LocationPermissionSheetModeTests {
    @Test("権限状態ごとに位置情報許可シナリオを分ける")
    func 権限状態ごとに位置情報許可シナリオを分ける() {
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .notDetermined,
                hasRequestedAlwaysLocationPermission: false
            )
                == .requestWhenInUseAndAlways
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .authorizedWhenInUse,
                hasRequestedAlwaysLocationPermission: false
            )
                == .requestAlways
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .authorizedWhenInUse,
                hasRequestedAlwaysLocationPermission: true
            )
                == .settings
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .denied,
                hasRequestedAlwaysLocationPermission: false
            )
                == .settings
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .restricted,
                hasRequestedAlwaysLocationPermission: false
            )
                == .settings
        )
        #expect(
            LocationPermissionSheetMode(
                authorizationStatus: .authorizedAlways,
                hasRequestedAlwaysLocationPermission: true
            ) == nil
        )
    }
}
