import CoreLocation
import Dependencies
import Foundation
import Shared
import Testing
@testable import iOSApp

// Every test explicitly installs these spies. Production dependency keys remain unchanged.
extension DependencyValues {
    mutating func installTestSpies() {
        self[MapLocationProviderKey.self] = MapLocationProviderSpy()
        self[BroadcastLocationProviderKey.self] = BroadcastLocationProviderSpy()
        self[HTTPClientKey.self] = HTTPClientSpy()
        self[FetchDistrictUseCaseKey.self] = FetchDistrictUseCaseSpy()
        self[UserDefaltsManagerKey.self] = DefaultUserDefaultsSpy()
        self.userDefaultsClient = UserDefaultsClientSpy().client
        self.authProvider = AuthProviderSpy().client
        self[ImageCacheClientKey.self] = ImageCacheClientSpy()
        self[AppStatusClientKey.self] = AppStatusClientSpy()
        self[AdManagerKey.self] = AdManagerSpy()
        self[SceneSessionCoordinatorKey.self] = SceneSessionCoordinatorSpy()
        self.values = .testFixture
    }
}

extension ConstantValues {
    static let testFixture = Self(
        apiBaseUrl: "",
        appStatusUrl: "",
        defaultFestivalKey: "region",
        defaultDistrictKey: "district",
        loginIdKey: "login",
        hasLaunchedBeforeKey: "hasLaunchedBefore",
        userGuideUrl: "",
        contactURL: "",
        isLiquidGlassEnabled: false,
        admobAppId: nil,
        publicMapInterstitialAdUnitId: nil,
        publicMapBannerAdUnitId: nil
    )
}

enum SpyInvocationError: Error {
    case unexpected(String)
}

actor MapLocationProviderSpy: MapLocationProviderProtocol {
    private(set) var isTracking = false
    private(set) var permissionRequests = 0
    private(set) var trackingStarts = 0
    private(set) var trackingStops = 0

    func requestPermission() async { permissionRequests += 1 }
    func startTracking() async {
        trackingStarts += 1
        isTracking = true
    }
    func stopTracking() async {
        trackingStops += 1
        isTracking = false
    }
    func getLocation() async -> AsyncValue<CLLocation> { .loading }
}

actor BroadcastLocationProviderSpy: BroadcastLocationProviderProtocol {
    private(set) var isTracking = false
    private(set) var permissionRequests = 0
    private(set) var trackingStarts = 0
    private(set) var trackingStops = 0
    var authorization: CLAuthorizationStatus = .notDetermined
    var servicesEnabled = false
    private var onAlwaysAuthorizationRequest: (@Sendable () async -> Void)?

    init(authorizationStatus: CLAuthorizationStatus = .notDetermined) {
        authorization = authorizationStatus
    }

    var startTrackingCallCount: Int { trackingStarts }

    func requestPermission(onAlwaysAuthorizationRequest: @escaping @Sendable () async -> Void) async {
        permissionRequests += 1
        self.onAlwaysAuthorizationRequest = onAlwaysAuthorizationRequest
    }
    func notifyAlwaysAuthorizationRequest() async {
        await onAlwaysAuthorizationRequest?()
    }
    func authorizationStatus() async -> CLAuthorizationStatus { authorization }
    func startTracking(onUpdate: ((AsyncValue<CLLocation>) async -> Void)?) async {
        trackingStarts += 1
        isTracking = true
    }
    func stopTracking() async {
        trackingStops += 1
        isTracking = false
    }
    func getLocation() async -> AsyncValue<CLLocation> { .loading }
    func isAlwaysAuthorized() async -> Bool { authorization == .authorizedAlways }
    func isLocationServicesEnabled() async -> Bool { servicesEnabled }
}

actor HTTPClientSpy: HTTPClientProtocol {
    private(set) var calls: [String] = []

    private func unexpected(_ operation: String, path: String) -> SpyInvocationError {
        let call = "\(operation) \(path)"
        calls.append(call)
        Issue.record("HTTPClientSpy: unexpected request \(call)")
        return .unexpected(call)
    }

    func request<Response: Decodable, Body: Encodable>(
        path: String, method: String, query: [String: Any], body: Body?,
        accessToken: String?, isCache: Bool
    ) async throws -> Response {
        throw unexpected(method, path: path)
    }

    func request<Response: Decodable>(
        path: String, method: String, query: [String: Any],
        accessToken: String?, isCache: Bool
    ) async throws -> Response {
        throw unexpected(method, path: path)
    }

    func get<Response: Decodable>(
        path: String, query: [String: Any], accessToken: String?, isCache: Bool
    ) async throws -> Response {
        throw unexpected("GET", path: path)
    }

    func post<Response: Decodable, Body: Encodable>(
        path: String, body: Body, query: [String: Any], accessToken: String?
    ) async throws -> Response {
        throw unexpected("POST", path: path)
    }

    func put<Response: Decodable, Body: Encodable>(
        path: String, body: Body, query: [String: Any], accessToken: String?
    ) async throws -> Response {
        throw unexpected("PUT", path: path)
    }

    func delete<Response: Decodable>(
        path: String, query: [String: Any], accessToken: String?
    ) async throws -> Response {
        throw unexpected("DELETE", path: path)
    }

    func delete(path: String, query: [String: Any], accessToken: String?) async throws {
        throw unexpected("DELETE", path: path)
    }
}

actor AuthProviderSpy {
    private(set) var calls: [String] = []

    private func unexpected(_ name: String) -> SpyInvocationError {
        calls.append(name)
        Issue.record("AuthProviderSpy: unexpected call \(name)")
        return .unexpected(name)
    }

    nonisolated var client: AuthProvider {
        AuthProvider(
            initialize: { throw SpyInvocationError.unexpected("AuthProvider.initialize") },
            signIn: { _, _ in throw await self.unexpected("signIn") },
            confirmSignIn: { _ in throw await self.unexpected("confirmSignIn") },
            getUserRole: { throw await self.unexpected("getUserRole") },
            getTokens: { throw await self.unexpected("getTokens") },
            signOut: { throw await self.unexpected("signOut") },
            changePassword: { _, _ in throw await self.unexpected("changePassword") },
            resetPassword: { _ in throw await self.unexpected("resetPassword") },
            confirmResetPassword: { _, _, _ in throw await self.unexpected("confirmResetPassword") },
            updateEmail: { _ in throw await self.unexpected("updateEmail") },
            confirmUpdateEmail: { _ in throw await self.unexpected("confirmUpdateEmail") }
        )
    }
}

final class UserDefaultsClientSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var strings: [String: String] = [:]
    private var recorded: [String] = []

    var calls: [String] { lock.withLock { recorded } }

    private func record(_ action: String) {
        lock.withLock { recorded.append(action) }
    }

    var client: UserDefaultsClient {
        UserDefaultsClient(
            string: { key in
                self.lock.withLock {
                    self.recorded.append("string:\(key)")
                    return self.strings[key]
                }
            },
            bool: { key in self.record("bool:\(key)"); return false },
            data: { key in self.record("data:\(key)"); return nil },
            double: { key in self.record("double:\(key)"); return 0 },
            integer: { key in self.record("integer:\(key)"); return 0 },
            remove: { key in
                self.lock.withLock {
                    self.recorded.append("remove:\(key)")
                    self.strings.removeValue(forKey: key)
                }
            },
            setString: { value, key in
                self.lock.withLock {
                    self.recorded.append("setString:\(key)")
                    self.strings[key] = value
                }
            },
            setBool: { _, key in self.record("setBool:\(key)") },
            setData: { _, key in self.record("setData:\(key)") },
            setDouble: { _, key in self.record("setDouble:\(key)") },
            setInteger: { _, key in self.record("setInteger:\(key)") }
        )
    }
}

final class DefaultUserDefaultsSpy: UserDefalutsManagerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var festivalId: String?
    private var districtId: String?
    private var alwaysPermissionRequested = false
    private var recorded: [String] = []

    init(hasRequestedAlwaysLocationPermission: Bool = false) {
        alwaysPermissionRequested = hasRequestedAlwaysLocationPermission
    }

    var calls: [String] { lock.withLock { recorded } }
    var defaultFestivalId: String? { lock.withLock { festivalId } }
    var defaultDistrictId: String? { lock.withLock { districtId } }
    var hasRequestedAlwaysLocationPermission: Bool { lock.withLock { alwaysPermissionRequested } }

    func saveDefaultFestivalId(_ value: String?) {
        lock.withLock {
            recorded.append("saveFestival")
            festivalId = value
        }
    }
    func saveDefaultDistrictId(_ value: String?) {
        lock.withLock {
            recorded.append("saveDistrict")
            districtId = value
        }
    }
    func saveHasRequestedAlwaysLocationPermission(_ value: Bool) {
        lock.withLock {
            recorded.append("saveAlwaysPermission")
            alwaysPermissionRequested = value
        }
    }
}

actor ImageCacheClientSpy: ImageCacheClientProtocol {
    private(set) var requests: [[String?]] = []
    func preload(paths: [String?]) async { requests.append(paths) }
}

actor AppStatusClientSpy: AppStatusClientProtocol {
    private(set) var requestedVersions: [String] = []
    func checkStatus() async -> StatusCheckResult? {
        requestedVersions.append("current")
        return nil
    }
    func checkStatus(currentVersion: String) async -> StatusCheckResult? {
        requestedVersions.append(currentVersion)
        return nil
    }
    static func getCurrentVersion() -> String { "0.0.0" }
}

final class AdManagerSpy: AdManagerProtocol, @unchecked Sendable {
    let isEnabled = false
    @MainActor private(set) var calls: [String] = []
    @MainActor func configureIfNeeded() { calls.append("configure") }
    @MainActor func preloadInterstitial(for placement: AdPlacement) { calls.append("preload") }
    @MainActor func presentInterstitial(for placement: AdPlacement) { calls.append("present") }
}

actor SceneSessionCoordinatorSpy: SceneSessionCoordinatorProtocol {
    private var sessionId = UUID()
    private(set) var sessionStarts = 0
    func beginSession() -> UUID {
        sessionStarts += 1
        sessionId = UUID()
        return sessionId
    }
    func isCurrent(_ id: UUID) -> Bool { sessionId == id }
}

actor FetchFestivalListUseCaseSpy: FetchFestivalListUseCaseProtocol {
    let festivals: [Festival]
    private(set) var callCount = 0

    init(festivals: [Festival]) { self.festivals = festivals }

    func callAsFunction() async throws -> [Festival] {
        callCount += 1
        return festivals
    }
}
