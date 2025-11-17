//
//  DistrictRepository.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/10/27.
//

import Dependencies

struct UserRepository: Repository {
    var get: @Sendable (_ name: String)  async throws -> String
}

extension DependencyValues {
  var userRepository: UserRepository {
    get { self[UserRepository.self] }
    set { self[UserRepository.self] = newValue }
  }
}

extension UserRepository {
    static let liveValue = Self(
        get: { name in
            "Hello \(name) !"
        }
    )
}


