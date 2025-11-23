//
//  FestivalController.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum FestivalControllerKey: DependencyKey {
    static let liveValue: any FestivalControllerProtocol = FestivalController()
}


// MARK: - FestivalControllerProtocol
protocol FestivalControllerProtocol: Sendable {
    func get(_ request: Request, next: Handler) async throws -> Response
    func scan(_ request: Request, next: Handler) async throws -> Response
    func put(_ request: Request, next: Handler) async throws -> Response
}

// MARK: - FestivalController
struct FestivalController: FestivalControllerProtocol {

    @Dependency(FestivalUsecaseKey.self) var usecase

    init() {}

    func get(_ request: Request, next: Handler) async throws -> Response {
        guard let id = request.parameters["id"] else { throw Error.decodingError() }
        let item = try await usecase.get(id)
        let body: String = try encode(item)
        return .init(statusCode: 200, headers: [:], body: body)
    }

    public func scan(_ request: Request, next: Handler) async throws -> Response {
        let items = try await usecase.scan()
        let body: String = try encode(items)
        return .init(statusCode: 200, headers: [:], body: body)
    }

    public func put(_ request: Request, next: Handler) async throws -> Response {
        guard let bodyStr = request.body else { throw Error.decodingError() }
        let festival = try decode(Festival.self, bodyStr)
        let user = request.user ?? .guest
        let result = try await usecase.post(festival, user: user)
        let body: String = try encode(result)
        return .init(statusCode: 200, headers: [:], body: body)
    }
}
