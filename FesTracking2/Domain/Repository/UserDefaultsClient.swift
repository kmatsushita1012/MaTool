//
//  LocalRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies

public struct UserDefaultsClient {
      public var boolForKey: @Sendable (String) -> Bool
      public var dataForKey: @Sendable (String) -> Data?
      public var doubleForKey: @Sendable (String) -> Double
      public var integerForKey: @Sendable (String) -> Int
      public var remove: @Sendable (String) async -> Void
      public var setBool: @Sendable (Bool, String) async -> Void
      public var setData: @Sendable (Data?, String) async -> Void
      public var setDouble: @Sendable (Double, String) async -> Void
      public var setInteger: @Sendable (Int, String) async -> Void
}

extension UserDefaultsClient{
    public static let noop = Self(
        boolForKey: { _ in return true },
        dataForKey: { _ in return nil},
        doubleForKey: { _ in return 0.0},
        integerForKey: { _ in return 0},
        remove: { _ in return },
        setBool: { _,_  in return },
        setData: { _,_ in return },
        setDouble: { _,_ in return },
        setInteger:  { _,_ in return }
    )
}

extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
    get { self[UserDefaultsClient.self] }
    set { self[UserDefaultsClient.self] = newValue }
  }
}
