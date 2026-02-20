//
//  LocationInjector.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/15.
//

import Testing
@testable import Backend
import Shared
import Dependencies
import Foundation

struct LocationInjector {
    @Test(.disabled()) func inject_location() async throws {
        let location = FloatLocation(id: UUID().uuidString, districtId: "test_district", coordinate: .init(latitude: 34.772985, longitude: 138.013809), timestamp: Date())
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            LocationRepository()
        }
        try await subject.put(location, festivalId: "test_region")
    }
}
