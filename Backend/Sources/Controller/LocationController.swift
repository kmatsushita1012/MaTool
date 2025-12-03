//
//  LocationController.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/02.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum LocationControllerKey: DependencyKey {
	static let liveValue: any LocationControllerProtocol = LocationController()
}

// MARK: - LocationControllerProtocol
protocol LocationControllerProtocol: Sendable {
	func get(_ request: Request, next: Handler) async throws -> Response
	func query(_ request: Request, next: Handler) async throws -> Response
	func put(_ request: Request, next: Handler) async throws -> Response
	func delete(_ request: Request, next: Handler) async throws -> Response
}

// MARK: - LocationController
struct LocationController: LocationControllerProtocol {

	@Dependency(LocationUsecaseKey.self) var usecase

	init() {}

	func get(_ request: Request, next: Handler) async throws -> Response {
		let districtId = try request.parameter("districtId", as: String.self)
		let user = request.user ?? .guest
		let result = try await usecase.get(districtId, user: user)
		return try .success(result)
	}

	func query(_ request: Request, next: Handler) async throws -> Response {
		let festivalId = try request.parameter("festivalId", as: String.self)
		let user = request.user ?? .guest
		let result = try await usecase.query(by: festivalId, user: user, now: .now)
		return try .success(result)
	}

	func put(_ request: Request, next: Handler) async throws -> Response {
		let body = try request.body(as: FloatLocation.self)
		let user = request.user ?? .guest
		let result = try await usecase.put(body, user: user)
		return try .success(result)
	}

	func delete(_ request: Request, next: Handler) async throws -> Response {
		let districtId = try request.parameter("districtId", as: String.self)
		let user = request.user ?? .guest
		try await usecase.delete(districtId, user: user)
        return try .success()
	}
}

