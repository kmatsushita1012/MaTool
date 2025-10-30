//
//  LocalMockClient.swift
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
