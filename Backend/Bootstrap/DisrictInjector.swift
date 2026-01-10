//
//  DisrictInjector.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/10.
//

import Testing
@testable import Backend
import Shared
import Foundation
import Dependencies

@Suite("District Injector")
struct DistrictInjector {
    @Test
    func inject_district() async throws  {
        let district = District(id: "test_district", name: "テスト町", festivalId: "test_region")
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            DistrictRepository()
        }
        _ = try await subject.post(item: district)
    }
    
    @Test
    func inject_performance() async throws {
        let district = Performance(id: "test_district", name: "テスト町", districtId: "test_region")
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            PerformanceRepository()
        }
        _ = try await subject.post(district)
    }
}

