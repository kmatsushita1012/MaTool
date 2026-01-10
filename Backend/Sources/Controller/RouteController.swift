//
//  RouteController.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/30.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum RouteControllerKey: DependencyKey {
	static let liveValue: any RouteControllerProtocol = RouteController()
}

// MARK: - RouteControllerProtocol
protocol RouteControllerProtocol: Sendable {
	func get(_ request: Request, next: Handler) async throws -> Response
	func query(_ request: Request, next: Handler) async throws -> Response
	func getIds(_ request: Request, next: Handler) async throws -> Response
	func post(_ request: Request, next: Handler) async throws -> Response
	func put(_ request: Request, next: Handler) async throws -> Response
	func delete(_ request: Request, next: Handler) async throws -> Response
}

// MARK: - RouteController
struct RouteController: RouteControllerProtocol {

	@Dependency(RouteUsecaseKey.self) var usecase

	init() {}

	func get(_ request: Request, next: Handler) async throws -> Response {
		let id = try request.parameter("routeId", as: String.self)
		let user = request.user ?? .guest
		let result = try await usecase.get(id: id, user: user)
		return try .success(result)
	}

	func query(_ request: Request, next: Handler) async throws -> Response {
		let districtId = try request.parameter("districtId", as: String.self)
		let user = request.user ?? .guest
		let result = try await usecase.query(by: districtId, user: user)
		return try .success(result)
	}

	func getIds(_ request: Request, next: Handler) async throws -> Response {
		let user = request.user ?? .guest
		let result = try await usecase.getAllRouteIds(user: user)
		return try .success(result)
	}

	func post(_ request: Request, next: Handler) async throws -> Response {
		let districtId = try request.parameter("districtId", as: String.self)
		let body = try request.body(as: Route.self)
		let user = request.user ?? .guest
		let result = try await usecase.post(districtId: districtId, route: body, user: user)
		return try .success(result)
	}

	func put(_ request: Request, next: Handler) async throws -> Response {
		let id = try request.parameter("routeId", as: String.self)
		let body = try request.body(as: Route.self)
		let user = request.user ?? .guest
		let result = try await usecase.put(id: id, route: body, user: user)
		return try .success(result)
	}

	func delete(_ request: Request, next: Handler) async throws -> Response {
		let id = try request.parameter("routeId", as: String.self)
		let user = request.user ?? .guest
		try await usecase.delete(id: id, user: user)
		return try .success()
	}
}

