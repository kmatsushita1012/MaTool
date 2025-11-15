//
//  RepositoryMocks.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Foundation
import Shared

@testable import Backend

// MARK: - FestivalRepositoryMock
struct FestivalRepositoryMock: FestivalRepositoryProtocol {
    private let response = Festival(
        id: "id", name: "name", subname: "sub", description: "description",
        prefecture: "prefecture", city: "city", base: Coordinate(latitude: 0.0, longitude: 0.0),
        spans: [], milestones: [], imagePath: "imagePath")

    func get(id: String) async throws -> Festival? { response }

    func scan() async throws -> [Festival] { [response] }

    func put(_ item: Festival) async throws {}
}

// MARK: - DistrictRepositoryMock
struct DistrictRepositoryMock: DistrictRepositoryProtocol {
    static let response = District(
        id: "id", name: "name", festivalId: "festivalId", visibility: .all)

    func get(id: String) async throws -> District? {
        return Self.response
    }

    func query(by festivalId: String) async throws -> [District] {
        return [Self.response]
    }

    func put(id: String, item: District) async throws {}

    func post(item: District) async throws {}
}

// MARK: - RouteRepositoryMock
struct RouteRepositoryMock: RouteRepositoryProtocol {
    static let response = Route(
        id: "id", districtId: "districtId", start: SimpleTime(hour: 0, minute: 0),
        goal: SimpleTime(hour: 23, minute: 59))

    func get(id: String) async throws -> Route? { Self.response }

    func query(by districtId: String) async throws -> [Route] { [Self.response] }

    func post(_ route: Route) async throws {}

    func put(_ route: Route) async throws {}

    func delete(id: String) async throws {}
}

// MARK: - LocationRepositoryMock
struct LocationRepositoryMock: LocationRepositoryProtocol {
    static let response = FloatLocation(
        districtId: "districtId", coordinate: Coordinate(latitude: 0, longitude: 0),
        timestamp: Date.now)

    func get(id: String) async throws -> FloatLocation? { Self.response }

    func getAll() async throws -> [FloatLocation] { [Self.response] }

    func put(_ location: FloatLocation) async throws {}

    func delete(districtId: String) async throws {}
}
