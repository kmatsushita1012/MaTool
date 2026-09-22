import Dependencies
import Foundation

public struct UserDefaultsClient: Sendable {
    public var string: @Sendable (String) -> String?
    public var contains: @Sendable (String) -> Bool
    public var bool: @Sendable (String) -> Bool
    public var data: @Sendable (String) -> Data?
    public var double: @Sendable (String) -> Double
    public var integer: @Sendable (String) -> Int
    public var remove: @Sendable (String) async -> Void
    public var setString: @Sendable (String?, String) -> Void
    public var setBool: @Sendable (Bool?, String) -> Void
    public var setData: @Sendable (Data?, String) -> Void
    public var setDouble: @Sendable (Double?, String) -> Void
    public var setInteger: @Sendable (Int?, String) -> Void

    public init(
        string: @escaping @Sendable (String) -> String?,
        contains: @escaping @Sendable (String) -> Bool,
        bool: @escaping @Sendable (String) -> Bool,
        data: @escaping @Sendable (String) -> Data?,
        double: @escaping @Sendable (String) -> Double,
        integer: @escaping @Sendable (String) -> Int,
        remove: @escaping @Sendable (String) async -> Void,
        setString: @escaping @Sendable (String?, String) -> Void,
        setBool: @escaping @Sendable (Bool?, String) -> Void,
        setData: @escaping @Sendable (Data?, String) -> Void,
        setDouble: @escaping @Sendable (Double?, String) -> Void,
        setInteger: @escaping @Sendable (Int?, String) -> Void
    ) {
        self.string = string
        self.contains = contains
        self.bool = bool
        self.data = data
        self.double = double
        self.integer = integer
        self.remove = remove
        self.setString = setString
        self.setBool = setBool
        self.setData = setData
        self.setDouble = setDouble
        self.setInteger = setInteger
    }
}

public enum UserDefaultsClientKey: DependencyKey {
    public static let liveValue: UserDefaultsClient = DependencyConfiguration.missing("UserDefaultsClient")
}

public extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClientKey.self] }
        set { self[UserDefaultsClientKey.self] = newValue }
    }
}

public protocol UserDefalutsManagerProtocol: Sendable {
    var defaultFestivalId: String? { get set }
    var defaultDistrictId: String? { get set }
}

public enum UserDefaltsManagerKey: DependencyKey {
    public static let liveValue: any UserDefalutsManagerProtocol = DependencyConfiguration.missing("UserDefaltsManager")
}

public extension DependencyValues {
    var userDefaltsManager: any UserDefalutsManagerProtocol {
        get { self[UserDefaltsManagerKey.self] }
        set { self[UserDefaltsManagerKey.self] = newValue }
    }
}
