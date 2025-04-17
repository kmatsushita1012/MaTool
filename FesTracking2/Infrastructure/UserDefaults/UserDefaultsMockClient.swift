//
//  LocalMockClient.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/07.
//
import Dependencies

extension UserDefaultsClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    stringForKey: unimplemented("\(Self.self).stringForKey", placeholder: nil),
    boolForKey: unimplemented("\(Self.self).boolForKey", placeholder: false),
    dataForKey: unimplemented("\(Self.self).dataForKey", placeholder: nil),
    doubleForKey: unimplemented("\(Self.self).doubleForKey", placeholder: 0),
    integerForKey: unimplemented("\(Self.self).integerForKey", placeholder: 0),
    remove: unimplemented("\(Self.self).remove"),
    setString: unimplemented("\(Self.self).setBool"),
    setBool: unimplemented("\(Self.self).setBool"),
    setData: unimplemented("\(Self.self).setData"),
    setDouble: unimplemented("\(Self.self).setDouble"),
    setInteger: unimplemented("\(Self.self).setInteger")
  )
}
