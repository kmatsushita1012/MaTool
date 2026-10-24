import ComposableArchitecture
import Dependencies

enum LastMainScreen: String, Equatable, Sendable {
    case map
    case admin
}

protocol LastMainScreenUseCaseProtocol: Sendable {
    func load() -> LastMainScreen?
    func save(_ screen: LastMainScreen?)
}

struct LastMainScreenUseCase: LastMainScreenUseCaseProtocol {
    private static let key = "lastMainScreen"

    @Dependency(\.userDefaultsClient) private var userDefaults

    func load() -> LastMainScreen? {
        userDefaults.string(Self.key).flatMap(LastMainScreen.init(rawValue:))
    }

    func save(_ screen: LastMainScreen?) {
        userDefaults.setString(screen?.rawValue, Self.key)
    }
}

enum LastMainScreenUseCaseKey: DependencyKey {
    static let liveValue: any LastMainScreenUseCaseProtocol = LastMainScreenUseCase()
}
