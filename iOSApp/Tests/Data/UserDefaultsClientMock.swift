//
//  UserDefaultsClientMock.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/07.
//
@testable import iOSApp

extension UserDefaultsClient {
    static let noop = Self(
        string: { _ in nil },
        bool: { _ in false },
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
