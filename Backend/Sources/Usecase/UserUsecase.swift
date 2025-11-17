//
//  DistrictUsecase.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/10/27.
//

import Dependencies

struct UserUsecase: Usecase {
    var get: @Sendable (_ name: String) async throws -> String
}

extension DependencyValues {
  var userUsecase: UserUsecase {
    get { self[UserUsecase.self] }
    set { self[UserUsecase.self] = newValue }
  }
}

extension UserUsecase {
    static let liveValue = {
        @Dependency(\.userRepository) var repository
        
        return Self(
            get: { name in
                try await repository.get(name)
            }
        )
    }()
}
