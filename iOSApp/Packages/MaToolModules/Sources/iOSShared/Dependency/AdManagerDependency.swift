import Dependencies

public enum AdPlacement: Hashable, Sendable {
    case publicMapInterstitial
}

public protocol AdManagerProtocol: Sendable {
    @MainActor
    func configureIfNeeded()
    @MainActor
    func preloadInterstitial(for placement: AdPlacement)
    @MainActor
    func presentInterstitial(for placement: AdPlacement)
}

public enum AdManagerKey: DependencyKey {
    public static let liveValue: any AdManagerProtocol = DependencyConfiguration.missing("AdManager")
}

public extension DependencyValues {
    var adManager: any AdManagerProtocol {
        get { self[AdManagerKey.self] }
        set { self[AdManagerKey.self] = newValue }
    }
}
