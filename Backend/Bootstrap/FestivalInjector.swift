//
//  FestivalInjector.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/10.
//

import Testing
@testable import Backend
import Shared
import Foundation
import Dependencies

@Suite("FestivalInjector")
struct FestivalInjector {
    
    @Test func inject_festival() async throws {
        let festival: Festival = .init(
            id: "test_region",
            name: "テスト祭典",
            subname: "テスト本部",
            prefecture: "大阪県",
            city: "豊中市", base: .init(latitude: 0.0, longitude: 0.0))
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0)}
        }) {
            FestivalRepository()
        }
        
        _ = try await subject.put(festival)
    }
    
    @Test func inject_checkopoint() async throws {
        let checkpoint: Checkpoint = .init(id: UUID().uuidString, name: "イシバシヤ", festivalId: "test_region", description: "なし")
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0)}
        }) {
            CheckpointRepository()
        }
        
        _ = try await subject.post(checkpoint)
    }
    
    @Test func inject_hazardSection() async throws {
        let hazardSection: HazardSection = .init(id: UUID().uuidString, title: "斜度5%", festivalId: "test_region")
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0)}
        }) {
            HazardSectionRepository()
        }
        
        _ = try await subject.put(hazardSection)
    }
    
    @Test
    func move_festival() async throws {
        let migrator = try DynamoDBMigrator(tableName: "matool_regions")
        let results = try await migrator.scan(Legacy.Region.self)
        
        var festivals: [Festival] = []
        var checkpoints: [Checkpoint] = []
        
        for result in results {
            festivals.append(
                Festival(
                    id: result.id,
                    name: result.name,
                    subname: result.subname,
                    description: result.description,
                    prefecture: result.prefecture,
                    city: result.city,
                    base: result.base,
                    image: .init(light: result.imagePath)
                )
            )
            for checkpoint in result.milestones {
                checkpoints.append(
                    Checkpoint(
                        id: checkpoint.id,
                        name: checkpoint.name,
                        festivalId: result.id,
                        description: checkpoint.description
                    )
                )
            }
        }
            
//        let festivalRepository = withDependencies({
//            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0)}
//        }) {
//            FestivalRepository()
//        }
//        
//        for festival in festivals {
//            _ = try await festivalRepository.put(festival)
//        }
        
        let checkpointRepository = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0)}
        }) {
            CheckpointRepository()
        }

        for checkpoint in checkpoints {
            _ = try await checkpointRepository.put(checkpoint)
        }
        
    }
}

