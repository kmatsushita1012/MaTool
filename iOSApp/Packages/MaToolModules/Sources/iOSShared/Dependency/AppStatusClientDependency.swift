import Dependencies

public protocol AppStatusClientProtocol: Sendable {
    func checkStatus() async -> StatusCheckResult?
    func checkStatus(currentVersion: String) async -> StatusCheckResult?
    static func getCurrentVersion() -> String
}

public enum AppStatusClientKey: DependencyKey {
    public static let liveValue: any AppStatusClientProtocol = DependencyConfiguration.missing("AppStatusClient")
}

public extension DependencyValues {
    var appStatusClient: any AppStatusClientProtocol {
        get { self[AppStatusClientKey.self] }
        set { self[AppStatusClientKey.self] = newValue }
    }
}
