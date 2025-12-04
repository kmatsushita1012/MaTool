//
//  FestivalRepositoryTest.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Testing
import Dependencies
import Shared
@testable import Backend

struct FestivalRepositoryTest {

    let festival: Festival = Festival(
        id: "ID",
        name: "NAME",
        subname: "SUBNAME",
        description: "DESCRIPTION",
        prefecture: "PREFECTURE",
        city: "CITY",
        base: Coordinate(
            latitude: 0.0, longitude: 0.0
        ),
        periods: [],
        checkpoints: [],
        imagePath: "IMAGE_PATH"
    )
    let dataStore: DataStoreMock<String, Festival>
    let subject: FestivalRepository

    init() {
        let dataStore = DataStoreMock<String, Festival>(response: festival)
        self.dataStore = dataStore

        self.subject = withDependencies {
            $0.dataStoreFactory = { _ in dataStore }
        } operation: {
            FestivalRepository()
        }
    }

    @Test func test_get_正常() async throws {
        let result = try await subject.get(id: "ID")

        #expect(dataStore.getCallCount == 1)
        let arg = try #require(dataStore.getArg)
        #expect(arg.0 == "ID")
        #expect(arg.1 == "id")
        #expect(arg.2 == Festival.self)

        let item = try #require(result)
        #expect(item.id == "ID")
        #expect(item.name == "NAME")
    }

    @Test func test_scan_正常() async throws {
        let result = try await subject.scan()

        #expect(dataStore.scanCallCount == 1)
        #expect(dataStore.scanArg == Festival.self)

        let item = try #require(result.first)
        #expect(item.id == "ID")
        #expect(item.name == "NAME")
    }

    @Test func test_put_正常() async throws {
        try await subject.put(festival)

        #expect(dataStore.putCallCount == 1)
        #expect(dataStore.putArg?.id == "ID")
        #expect(dataStore.putArg?.name == "NAME")
    }
}
