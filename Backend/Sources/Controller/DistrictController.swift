//
//  DistrictController.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/22.
//

//
//  DistrictController.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/22.
//

import Dependencies
import Shared

// MARK: - DistrictControllerProtocol
protocol DistrictControllerProtocol: Sendable {
	func get(_ request: Request, next: Handler) async throws -> Response
	func query(_ request: Request, next: Handler) async throws -> Response
	func post(_ request: Request, next: Handler) async throws -> Response
	func put(_ request: Request, next: Handler) async throws -> Response
    func updateDistrict(_ request: Request, next: Handler) async throws -> Response
}

// MARK: - DependencyKey
enum DistrictControllerKey: DependencyKey {
	static let liveValue: any DistrictControllerProtocol = DistrictController()
}

// MARK: - DistrictController (implementation)
struct DistrictController: DistrictControllerProtocol {
	@Dependency(DistrictUsecaseKey.self) var usecase

	init() {}

	func get(_ request: Request, next: Handler) async throws -> Response {
        let id = try request.parameter("districtId", as: String.self)
        let result = try await usecase.get(id)
        return try .success(result)
	}

	func query(_ request: Request, next: Handler) async throws -> Response {
        let regionId = try request.parameter("festivalId", as: String.self)
        let result = try await usecase.query(by: regionId)
        return try .success(result)
	}
    
	func post(_ request: Request, next: Handler) async throws -> Response {
        let regionId = try request.parameter("festivalId", as: String.self)
        let body = try request.body(as: DistrictCreateForm.self)
        let user = request.user ?? .guest
        let result = try await usecase.post(user: user, headquarterId: regionId, newDistrictName: body.name, email: body.email)
        return try .success(result)
	}

    func put(_ request: Request, next: Handler) async throws -> Response {
        let id = try request.parameter("districtId", as: String.self)
        let body = try request.body(as: DistrictPack.self)
        let user = request.user ?? .guest
        let result = try await usecase.put(id: id, item: body, user: user)
        return try .success(result)
	}
    
    func updateDistrict(_ request: Request, next: Handler) async throws -> Response {
        let id = try request.parameter("districtId", as: String.self)
        let body = try request.body(as: District.self)
        let user = request.user ?? .guest
        let result = try await usecase.put(id: id, district: body, user: user)
        return try .success(result)
    }
}
