//
//  LocalLiveClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/07.
//

import Dependencies
import Foundation


extension UserDefaultsClient: DependencyKey {
  public static let liveValue: Self = {
      let defaults = SafeUserDefaults(suiteName: "matool")
    return Self(
        string: { defaults.base.string(forKey: $0) },
        bool: { defaults.base.bool(forKey: $0) },
        data: { defaults.base.data(forKey: $0) },
        double: { defaults.base.double(forKey: $0) },
        integer: { defaults.base.integer(forKey: $0) },
        remove: { defaults.base.removeObject(forKey: $0) },
        setString: { defaults.base.set($0, forKey: $1) },
        setBool: { defaults.base.set($0, forKey: $1) },
        setData: { defaults.base.set($0, forKey: $1) },
        setDouble: { defaults.base.set($0, forKey: $1) },
        setInteger: { defaults.base.set($0, forKey: $1) }
    )
  }()
}

final class SafeUserDefaults: @unchecked Sendable {
    let base: UserDefaults
    init(suiteName: String? = nil) {
        self.base = UserDefaults(suiteName: suiteName) ?? .standard
    }
}
