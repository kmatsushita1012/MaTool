import iOSShared
//
//  UserDefaultsClient.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies

// MARK: - UserDefaultsClient
extension UserDefaultsClient {
  public static let infrastructureLiveValue: Self = {
    let defaults = { UserDefaults(suiteName: "matool")! }
    return Self(
        string: { defaults().string(forKey: $0) },
        contains: { defaults().object(forKey: $0) != nil },
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

public struct UserDefaltsManager: Sendable {
    enum Key: String {
        case defaultFestivalId = "region"
        case defaultDistrictId = "district"
    }
    private let defaults = UserDefaults(suiteName: "matool")!

    public init() {}
}

extension UserDefaltsManager: UserDefalutsManagerProtocol {
    public var defaultFestivalId: String? {
        get {
            defaults.string(forKey: Key.defaultFestivalId.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Key.defaultFestivalId.rawValue)
        }
    }
    
    public var defaultDistrictId: String? {
        get {
            defaults.string(forKey: Key.defaultDistrictId.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Key.defaultDistrictId.rawValue)
        }
    }
}

extension UserDefaults: @retroactive @unchecked Sendable {}
