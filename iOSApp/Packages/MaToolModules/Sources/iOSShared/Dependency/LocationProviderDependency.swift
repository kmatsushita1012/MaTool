import CoreLocation
import Dependencies

public protocol LocationProviderProtocol: Sendable {
    func requestPermission() async
    func startTracking(backgroundUpdatesAllowed: Bool, onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async
    func stopTracking() async
    func getLocation() async -> AsyncValue<CLLocation>
    func isPermissionAllowed() async -> Bool
    var isTracking: Bool { get async }
}

public extension LocationProviderProtocol {
    func startTracking(
        backgroundUpdatesAllowed: Bool,
        onUpdate: ((AsyncValue<CLLocation>) async -> Void)? = nil
    ) async {
        await startTracking(backgroundUpdatesAllowed: backgroundUpdatesAllowed, onUpdate: onUpdate)
    }
}

public enum LocationProviderKey: DependencyKey {
    public static let liveValue: any LocationProviderProtocol = DependencyConfiguration.missing("LocationProvider")
}

public extension DependencyValues {
    var locationProvider: any LocationProviderProtocol {
        get { self[LocationProviderKey.self] }
        set { self[LocationProviderKey.self] = newValue }
    }
}
