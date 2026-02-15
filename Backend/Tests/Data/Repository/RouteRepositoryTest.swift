////
////  RouteRepositoryTest.swift
////  MaTool
////
////  Created by 松下和也 on 2025/11/14.
////
//
//import Testing
//import Dependencies
//import Shared
//@testable import Backend
//
//@Suite(.disabled())
//struct RouteRepositoryTest {
//    let route: Route
//    let dataStore: DataStoreMock<String, Route>
//    let subject: RouteRepository
//
//    init() {
//        self.route = Route(
//            id: "ID",
//            districtId: "DISTRICT_ID",
//            start: SimpleTime(hour: 0, minute: 0),
//            goal: SimpleTime(hour: 23, minute: 59)
//        )
//
//        let store = DataStoreMock<String, Route>(response: route)
//        self.dataStore = store
//
//        self.subject = withDependencies {
//            $0.dataStoreFactory = { _ in store }
//        } operation: {
//            RouteRepository()
//        }
//    }
//    
//    @Test func test_get_正常() async throws {
//        let result = try await subject.get(id: "ID")
//
//        #expect(dataStore.getCallCount == 1)
//        let args = try #require(dataStore.getArg)
//        #expect(args.0 == "ID")
//        #expect(args.1 == "id")
//        #expect(args.2 == Route.self)
//
//        let item = try #require(result)
//        #expect(item.id == "ID")
//        #expect(item.districtId == "DISTRICT_ID")
//        #expect(item.start == SimpleTime(hour: 0, minute: 0))
//        #expect(item.goal == SimpleTime(hour: 23, minute: 59))
//    }
//    
//    @Test func test_query_正常() async throws {
//        let result = try await subject.query(by: "DISTRICT_ID")
//
//        #expect(dataStore.queryCallCount == 1)
//        let args = try #require(dataStore.queryArg)
//
//        #expect(args.0 == "district_id-index")
//        switch args.1 {
//        case let .equals(field, value):
//            #expect(field == "district_id")
//            #expect(value as? String == "DISTRICT_ID")
//        default:
//            Issue.record("Expected .equals but got \(args.1)")
//        }
//        #expect(args.2 == nil)     // filter
//        #expect(args.3 == nil)     // limit
//        #expect(args.4 == true)    // ascending
//        #expect(args.5 == Route.self)
//
//        let item = try #require(result.first)
//        #expect(item.id == "ID")
//        #expect(item.districtId == "DISTRICT_ID")
//        #expect(item.start == SimpleTime(hour: 0, minute: 0))
//        #expect(item.goal == SimpleTime(hour: 23, minute: 59))
//    }
//
//    @Test func test_post_正常() async throws {
//        try await subject.post(route)
//
//        #expect(dataStore.putCallCount == 1)
//        let arg = try #require(dataStore.putArg)
//        #expect(arg.id == "ID")
//    }
//
//    @Test func test_put_正常() async throws {
//        try await subject.put(route)
//
//        #expect(dataStore.putCallCount == 1)
//        let arg = try #require(dataStore.putArg)
//        #expect(arg.id == "ID")
//    }
//
//    @Test func test_delete_正常() async throws {
//        try await subject.delete(id: "ID")
//
//        #expect(dataStore.deleteCallCount == 1)
//        let arg = try #require(dataStore.deleteArg)
//        #expect(arg.0 == "ID")
//        #expect(arg.1 == "id")
//    }
//}
