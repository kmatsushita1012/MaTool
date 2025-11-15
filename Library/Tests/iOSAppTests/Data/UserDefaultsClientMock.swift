//
//  UserDefaultsClientMock.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/07.
//
import Dependencies

extension UserDefaultsClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    string: unimplemented("\(Self.self).string", placeholder: nil),
    bool: unimplemented("\(Self.self).bool", placeholder: false),
    data: unimplemented("\(Self.self).data", placeholder: nil),
    double: unimplemented("\(Self.self).double", placeholder: 0),
    integer: unimplemented("\(Self.self).integer", placeholder: 0),
    remove: unimplemented("\(Self.self).remove"),
    setString: unimplemented("\(Self.self).setBool"),
    setBool: unimplemented("\(Self.self).setBool"),
    setData: unimplemented("\(Self.self).setData"),
    setDouble: unimplemented("\(Self.self).setDouble"),
    setInteger: unimplemented("\(Self.self).setInteger")
  )
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
