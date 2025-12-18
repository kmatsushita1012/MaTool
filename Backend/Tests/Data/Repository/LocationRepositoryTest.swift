//
//  LocationRepositoryTest.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Testing
import Dependencies
import Shared
@testable import Backend
import Foundation

@Suite(.disabled())
struct LocationRepositoryTest {

    let location = FloatLocation(
        districtId: "DISTRICT_ID",
        coordinate: Coordinate(latitude: 1.23, longitude: 4.56),
        timestamp: Date.now
    )
    let dataStore: DataStoreMock<String, FloatLocation>
    let subject: LocationRepository

    init() {
        let dataStore = DataStoreMock<String, FloatLocation>(response: location)
        self.dataStore = dataStore

        self.subject = withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            LocationRepository()
        }
    }
    
    @Test func test_get_正常() async throws {
        let result = try await subject.get(id: "DISTRICT_ID")
        
        
        #expect(dataStore.getCallCount == 1)
        let arg = try #require(dataStore.getArg)
        #expect(arg.0 == "DISTRICT_ID")
        #expect(arg.1 == "district_id")
        #expect(arg.2 == FloatLocation.self)

        let item = try #require(result)
        #expect(item.districtId == "DISTRICT_ID")
        #expect(item.coordinate.latitude == 1.23)
        #expect(item.coordinate.longitude == 4.56)
        #expect(item.timestamp == location.timestamp)
    }
    
    @Test func test_scan_正常() async throws {
        let result = try await subject.scan()
        
        
        #expect(dataStore.scanCallCount == 1)
        #expect(dataStore.scanArg == FloatLocation.self)

        let item = try #require(result.first)
        #expect(item.districtId == "DISTRICT_ID")
        #expect(item.coordinate.latitude == 1.23)
        #expect(item.coordinate.longitude == 4.56)
        #expect(item.timestamp == location.timestamp)

    }
    
    @Test func test_put_正常() async throws {
        let result = try await subject.put(location)
        
        
        #expect(dataStore.putCallCount == 1)
        #expect(result == location)
        let arg = try #require(dataStore.putArg)
        #expect(arg.districtId == "DISTRICT_ID")
        #expect(arg.coordinate.latitude == 1.23)
        #expect(arg.coordinate.longitude == 4.56)
        #expect(arg.timestamp == location.timestamp)
    }
    
    @Test func test_delete_正常() async throws {
        try await subject.delete(districtId: "DISTRICT_ID")
        
        
        #expect(dataStore.deleteCallCount == 1)
        let arg = try #require(dataStore.deleteArg)
        #expect(arg.0 == "DISTRICT_ID")
        #expect(arg.1 == "district_id")
    }
}
