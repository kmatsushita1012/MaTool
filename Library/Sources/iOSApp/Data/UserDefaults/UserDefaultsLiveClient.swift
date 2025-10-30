//
//  LocalLiveClient.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/07.
//

import Dependencies
import Foundation


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
