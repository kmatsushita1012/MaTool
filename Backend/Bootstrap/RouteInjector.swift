//
//  RouteInjector.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/12.
//

import Testing
@testable import Backend
import Shared
import Dependencies
import Foundation

struct RouteInjector {
    @Test func inject_routes() async throws {
        let route = Route(id: UUID().uuidString, districtId: "test_district", periodId: "88B4BE1E-1A22-4313-8070-58CF320240A6", visibility: .all, description: "")
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            RouteRepository()
        }
        _ = try await subject.post(route)
    }
    
    @Test func inject_points() async throws {
        let point = Point(id: UUID().uuidString, routeId: "B30822CB-62F0-4926-95B3-04145DDAA779", coordinate: .init(latitude: 0, longitude: 0), time: .now, checkpointId: nil, performanceId: nil, anchor: nil)
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            PointRepository()
        }
        _ = try await subject.post(point)
    }
}
