//
//  UserDefaultsClient.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies

// MARK: - Dependencies
extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
    get { self[UserDefaultsClient.self] }
    set { self[UserDefaultsClient.self] = newValue }
  }
}

// MARK: - UserDefaultsClient(Protocol)
struct UserDefaultsClient {
    public var string: @Sendable (String) -> String?
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
}

// MARK: - UserDefaultsClient
extension UserDefaultsClient: DependencyKey {
  public static let liveValue: Self = {
    let defaults = { UserDefaults(suiteName: "matool")! }
    return Self(
        string: { defaults().string(forKey: $0) },
        bool: { defaults().bool(forKey: $0) },
        data: { defaults().data(forKey: $0) },
        double: { defaults().double(forKey: $0) },
        integer: { defaults().integer(forKey: $0) },
        remove: { defaults().removeObject(forKey: $0) },
        setString: { defaults().set($0, forKey: $1) },
        setBool: { defaults().set($0, forKey: $1) },
        setData: { defaults().set($0, forKey: $1) },
        setDouble: { defaults().set($0, forKey: $1) },
        setInteger: { defaults().set($0, forKey: $1) }
    )
  }()
}

struct UserDefaltsManager: Sendable {
    enum Key: String {
        case defaultFestivalId = "region"
        case defaultDistrictId = "district"
    }
    let defaults = UserDefaults(suiteName: "matool")!
}

protocol UserDefalutsManagerProtocol: Sendable {
    var defaultFestivalId: String? { get set }
    var defaultDistrictId: String? { get set }
}

extension UserDefaltsManager: UserDefalutsManagerProtocol {
    var defaultFestivalId: String? {
        get {
            defaults.string(forKey: Key.defaultFestivalId.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Key.defaultFestivalId.rawValue)
        }
    }
    
    var defaultDistrictId: String? {
        get {
            defaults.string(forKey: Key.defaultDistrictId.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Key.defaultDistrictId.rawValue)
        }
    }
}

enum UserDefaltsManagerKey: DependencyKey {
    static let liveValue: UserDefalutsManagerProtocol = UserDefaltsManager()
}

extension UserDefaults: @retroactive @unchecked Sendable {}
