//
//  LocalRepository.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies

public struct UserDefaultsClient {
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

extension UserDefaultsClient{
    static let noop = Self(
        string: { _ in return "" },
        bool: { _ in return true },
        data: { _ in return nil},
        double: { _ in return 0.0},
        integer: { _ in return 0},
        remove: { _ in return },
        setString: { _,_  in return },
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

struct UserDefaulsKey{
    static let adminDistrict = "matool_district_admin"
}
