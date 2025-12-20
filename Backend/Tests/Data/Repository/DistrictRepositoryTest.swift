//
//  DistrictRepositoryTest.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Testing
import Dependencies
import Shared
@testable import Backend

//@Suite(.disabled())
//struct DistrictRepositoryTest {
//    let district = District(id: "ID", name: "NAME", festivalId: "FESTIVAL_ID", visibility: .all)
//    let dataStore: DataStoreMock<String, District>
//    let subject: DistrictRepository
//    
//    init() {        
//        let dataStore = DataStoreMock<String, District>(response: district)
//        self.dataStore = dataStore
//        
//        self.subject = withDependencies {
//            $0.dataStoreFactory = { _ in dataStore }
//        } operation: {
//            DistrictRepository()
//        }
//    }
//    
//    @Test func test_get_正常() async throws {
//        let result = try await subject.get(id: "ID")
//        
//        
//        #expect(dataStore.getCallCount == 1)
//        #expect(dataStore.getArg?.0 == "ID")
//        #expect(dataStore.getArg?.1 == "id")
//        #expect(dataStore.getArg?.2 == District.self)
//        
//        #expect(result?.id == "ID")
//        #expect(result?.name == "NAME")
//        #expect(result?.festivalId == "FESTIVAL_ID")
//        #expect(result?.visibility == .all)
//    }
//    
//    @Test func test_query_正常() async throws {
//        let result = try await subject.query(by: "festivalId")
//        
//        
//        #expect(dataStore.queryCallCount == 1)
//        let queryArg = try #require(dataStore.queryArg)
//        #expect(queryArg.0 == "region_id-index")
//        let (field, value) = try #require({
//            if case let .equals(field, value) = queryArg.1 {
//                return (field, value)
//            } else {
//                return nil
//            }
//        }())
//        #expect(field == "region_id")
//        #expect(value as? String == "festivalId")
//        #expect(queryArg.2 == nil)
//        #expect(queryArg.3 == nil)
//        #expect(queryArg.4 == true)
//        #expect(queryArg.5 == District.self)
//
//        #expect(result.count == 1)
//        let item = try #require(result.first)
//        #expect(item.id == "ID")
//        #expect(item.name == "NAME")
//        #expect(item.festivalId == "FESTIVAL_ID")
//        #expect(item.visibility == .all)
//    }
//    
//    @Test func test_put_正常() async throws {
//        try await subject.put(id: "id", item: district)
//        
//        
//        #expect(dataStore.putCallCount == 1)
//        let putArg = try #require(dataStore.putArg)
//        #expect(putArg.id == "ID")
//        #expect(putArg.name == "NAME")
//        #expect(putArg.festivalId == "FESTIVAL_ID")
//        #expect(putArg.visibility == .all)
//    }
//
//    @Test func test_post_正常() async throws {
//        try await subject.post(item: district)
//
//        #expect(dataStore.putCallCount == 1)
//        let putArg = try #require(dataStore.putArg)
//        #expect(putArg.id == "ID")
//        #expect(putArg.name == "NAME")
//        #expect(putArg.festivalId == "FESTIVAL_ID")
//        #expect(putArg.visibility == .all)
//    }
//}
