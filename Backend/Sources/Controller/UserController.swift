//
//  DistrictController.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/10/27.
//

import Dependencies
import Foundation

struct UserController: Controller {
    var get: Middleware
}

extension DependencyValues {
  var userController: UserController {
    get { self[UserController.self] }
    set { self[UserController.self] = newValue }
  }
}

extension UserController {
    static let liveValue = {
        @Dependency(\.userUsecase) var usecase
        
        return Self(
            get: { request, next in
                guard let name = request.parameters["name"] else {
                    return .decodeError
                }
                let result: String
                do {
                    result = try await usecase.get(name)
                } catch {
                    return .internalServerError
                }
                
                guard let body: String = try? encode(result) else {
                    return .encodeError
                }
                return .init(
                    statusCode: 200,
                    headers: [:],
                    body: body
                )
            }
        )
    }()
}
