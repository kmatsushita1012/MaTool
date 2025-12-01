//
//  RouteMigrator.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/01.
//

import Testing
import Shared
import Dependencies
@testable import Backend

@Suite(.disabled())
struct RouteMigrator {
    @Test
    func migrate() async throws {
        let repository: DistrictRepositoryProtocol = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0) }
        }) {
            DistrictRepository()
        }
        let districts = try await repository.query(by: "")
        
        // 既存の DynamoDBStore を使う
        let store = DynamoDBStore.make(tableName: "matool_routes")
        
        let migrator = DynamoDBMigrator(store: store)
        
        // Old → New への例示的な変換
        for district in districts {
            try await migrator.migrateWhere(
                oldType: OldRoute.self,
                newType: Route.self,
                indexName: "district_id-index",
                queryCondition: .equals("district_id", district.id),
            ) { old in
                Route(
                    id: old.id,
                    districtId: old.districtId,
                    date: old.date,
                    title: old.title,
                    visibility: district.visibility,
                    description: old.description,
                    points: old.points,
                    start: old.start,
                    goal: old.goal
                )
            }
        }
        #expect(true)
    }
    
    public struct OldRoute: Codable {
        public let id: String
        public let districtId: String
        public var date:SimpleDate = .today
        public var title: String = ""
        @NullEncodable public var description: String?
        public var points: [Point] = []
        public var start: SimpleTime
        public var goal: SimpleTime
        
        public init(
            id: String,
            districtId: String,
            date: SimpleDate = .today,
            title: String = "",
            description: String? = nil,
            points: [Point] = [],
            start: SimpleTime,
            goal: SimpleTime
        ) {
            self.id = id
            self.districtId = districtId
            self.date = date
            self.title = title
            self.description = description
            self.points = points
            self.start = start
            self.goal = goal
        }
    }
}
