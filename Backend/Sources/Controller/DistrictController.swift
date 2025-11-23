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
	func get(_ request: Request, next: Handler) async -> Response
	func query(_ request: Request, next: Handler) async -> Response
	func getTools(_ request: Request, next: Handler) async -> Response
	func post(_ request: Request, next: Handler) async -> Response
	func put(_ request: Request, next: Handler) async -> Response
}

// MARK: - DependencyKey
enum DistrictControllerKey: DependencyKey {
	static let liveValue: any DistrictControllerProtocol = DistrictController()
}

// MARK: - DistrictController (implementation)
struct DistrictController: DistrictControllerProtocol {
	@Dependency(DistrictUsecaseKey.self) var usecase

	init() {}

	func get(_ request: Request, next: Handler) async -> Response {
		guard let id = request.parameters["districtId"] else { return .decodeError }
		do {
			let item = try await usecase.get(id)
            let body: String = try encode(item)
			return .init(statusCode: 200, headers: [:], body: body)
		} catch {
			return .internalServerError
		}
	}

	func query(_ request: Request, next: Handler) async -> Response {
		guard let regionId = request.parameters["regionId"] else { return .decodeError }
		do {
			let items = try await usecase.query(by: regionId)
			let body: String = try encode(items)
			return .init(statusCode: 200, headers: [:], body: body)
		} catch {
			return .internalServerError
		}
	}

	func getTools(_ request: Request, next: Handler) async -> Response {
		guard let id = request.parameters["districtId"] else { return .decodeError }
		do {
			let tools = try await usecase.getTools(id: id, user: request.user ?? .guest)
			let body: String = try encode(tools)
			return .init(statusCode: 200, headers: [:], body: body)
		} catch {
			return .internalServerError
		}
	}

	func post(_ request: Request, next: Handler) async -> Response {
		struct PostBody: Decodable {
			let name: String
			let email: String
		}

		guard let regionId = request.parameters["regionId"] else { return .decodeError }
		guard let bodyStr = request.body else { return .decodeError }
		do {
			let form = try decode(PostBody.self, bodyStr)
			let user = request.user ?? .guest
			let result = try await usecase.post(user: user, headquarterId: regionId, newDistrictName: form.name, email: form.email)
			let body: String = try encode(result)
			return .init(statusCode: 200, headers: [:], body: body)
		} catch {
			return .internalServerError
		}
	}

    func put(_ request: Request, next: Handler) async -> Response {
		guard let id = request.parameters["districtId"] else { return .decodeError }
		guard let bodyStr = request.body else { return .decodeError }
		do {
			let item = try decode(District.self, bodyStr)
			let user = request.user ?? .guest
			let result = try await usecase.put(id: id, item: item, user: user)
			let body: String = try encode(result)
			return .init(statusCode: 200, headers: [:], body: body)
		} catch {
			return .internalServerError
		}
	}
}
