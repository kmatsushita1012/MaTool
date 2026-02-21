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
    @Test(.disabled())
    func inject_district() async throws  {
        let district = District(id: "test_district", name: "テスト町", festivalId: "test_region")
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            DistrictRepository()
        }
        _ = try await subject.post(item: district)
    }
    
    @Test(.disabled())
    func inject_performance() async throws {
        let district = Performance(id: UUID().uuidString, name: "テスト町", districtId: "test_district")
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            PerformanceRepository()
        }
        _ = try await subject.post(district)
    }
    
    @Test(.disabled())
    func move_district() async throws {
        let migrator = try DynamoDBMigrator(tableName: "matool_districts")
        let results = try await migrator.scan(Legacy.District.self)
        
        var districts: [District] = []
        var performances: [Performance] = []
        
        for (index, result) in results.enumerated() {
            districts.append(
                District(
                    id: result.id,
                    name: result.name,
                    festivalId: result.regionId,
                    order: index,
                    description: result.description,
                    base: result.base,
                    area: result.area,
                    image: .init(light: result.imagePath),
                    visibility: Visibility(rawValue: result.visibility.rawValue) ?? .all
                )
            )
            
            for performance in result.performances {
                performances.append(
                    Performance(
                        id: performance.id,
                        name: performance.name,
                        districtId: result.id,
                        performer: performance.performer,
                        description: performance.description
                    )
                )
            }
        }
        
        let districtRepository = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0)}
        }) {
            DistrictRepository()
        }
        
        for district in districts {
            _ = try await districtRepository.post(item: district)
        }
        
        let performanceRepository = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0)}
        }) {
            PerformanceRepository()
        }
        
        for performance in performances {
            _ = try await performanceRepository.post(performance)
        }
    }
}
