//
//  LocationControllerTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/02.
//

import Foundation
import Testing
@testable import Backend
import Dependencies
import Shared


struct LocationControllerTest {
    let next: Handler = { _ in throw TestError.unimplemented }
    let expectedHeaders: [String: String] = ["Content-Type": "application/json"]

    @Test func test_query_正常() async throws {
        let dto = FloatLocationGetDTO(districtId: "d-id", districtName: "d-name", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
        let expected = [dto]
        var lastFestivalId: String? = nil
        var lastUser: UserRole? = nil
        let mock = LocationUsecaseMock(queryHandler: { festivalId, user, now in
            lastFestivalId = festivalId
            lastUser = user
            return expected
        })

        let subject = makeUsecase(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"]) 

        
        let result = try await subject.query(request, next: next)

        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let body = try [FloatLocationGetDTO].from(result.body)
        #expect(body == expected)
        #expect(lastFestivalId == "f-id")
        #expect(lastUser == .guest)
        #expect(mock.queryCallCount == 1)
    }

    @Test func test_query_userがnil() async throws {
        let dto = FloatLocationGetDTO(districtId: "d-id", districtName: "d-name", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
        let expected = [dto]
        var lastFestivalId: String? = nil
        var lastUser: UserRole? = nil
        let mock = LocationUsecaseMock(queryHandler: { festivalId, user, _ in
            lastFestivalId = festivalId
            lastUser = user
            return expected
        })

        let subject = makeUsecase(mock)
        var request = makeRequest(method: .get, parameters: ["festivalId": "f-id"]) 
        request.user = nil

        
        let result = try await subject.query(request, next: next)

        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let body = try [FloatLocationGetDTO].from(result.body)
        #expect(body == expected)
        #expect(lastFestivalId == "f-id")
        #expect(lastUser == .guest)
        #expect(mock.queryCallCount == 1)
    }

    @Test func test_query_異常() async throws {
        let expectedError = Error.internalServerError("query_failed")
        var lastFestivalId: String? = nil
        var lastUser: UserRole? = nil
        let mock = LocationUsecaseMock(queryHandler: { festivalId, user, _ in
            lastFestivalId = festivalId
            lastUser = user
            throw expectedError
        })
        let subject = makeUsecase(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"]) 

        
        await #expect(throws: expectedError) {
            let _ = try await subject.query(request, next: next)
        }

        
        #expect(lastFestivalId == "f-id")
        #expect(lastUser == .guest)
        #expect(mock.queryCallCount == 1)
    }

    @Test func test_get_正常() async throws {
        let dto = FloatLocationGetDTO(districtId: "d-id", districtName: "d-name", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
        var lastCalledId: String? = nil
        var lastCalledUser: UserRole? = nil
        let mock = LocationUsecaseMock(getHandler: { id, user in
            lastCalledId = id
            lastCalledUser = user
            return dto
        })

        let subject = makeUsecase(mock)
        let request = makeRequest(method: .get, parameters: ["districtId": "d-id"]) 

        
        let result = try await subject.get(request, next: next)

        
        #expect(lastCalledId == "d-id")
        #expect(lastCalledUser == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let body = try FloatLocationGetDTO.from(result.body)
        #expect(body == dto)
        #expect(mock.getCallCount == 1)
    }

    @Test func test_get_userがnil() async throws {
        let dto = FloatLocationGetDTO(districtId: "d-id", districtName: "d-name", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
        var lastCalledId: String? = nil
        var lastCalledUser: UserRole? = nil
        let mock = LocationUsecaseMock(getHandler: { id, user in
            lastCalledId = id
            lastCalledUser = user
            return dto
        })

        let subject = makeUsecase(mock)
        var request = makeRequest(method: .get, parameters: ["districtId": "d-id"], user: nil)

        
        let result = try await subject.get(request, next: next)

        
        #expect(lastCalledId == "d-id")
        #expect(lastCalledUser == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let body = try FloatLocationGetDTO.from(result.body)
        #expect(body == dto)
        #expect(mock.getCallCount == 1)
    }

    @Test func test_get_異常() async throws {
        let expectedError = Error.internalServerError("get_failed")
        var lastCalledId: String? = nil
        let mock = LocationUsecaseMock(getHandler: { id, _ in
            lastCalledId = id
            throw expectedError
        })

        let subject = makeUsecase(mock)
        let request = makeRequest(method: .get, parameters: ["districtId": "d-id"]) 

        
        await #expect(throws: expectedError) {
            let _ = try await subject.get(request, next: next)
        }

        
        #expect(lastCalledId == "d-id")
        #expect(mock.getCallCount == 1)
    }

    @Test func test_put_正常() async throws {
        let location = FloatLocation(districtId: "d-id", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
        let bodyString = try location.toString()
        var lastCalledLocation: FloatLocation? = nil
        var lastCalledUser: UserRole? = nil
        let mock = LocationUsecaseMock(putHandler: { item, user in
            lastCalledLocation = item
            lastCalledUser = user
            return item
        })
        let subject = makeUsecase(mock)
        let request = makeRequest(method: .put, user: .district("d-id"), body: bodyString)

        
        let result = try await subject.put(request, next: next)

        
        #expect(lastCalledLocation == location)
        #expect(lastCalledUser == .district("d-id"))
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let body = try FloatLocation.from(result.body)
        #expect(body == location)
    }

    @Test func test_put_userがnil() async throws {
        let location = FloatLocation(districtId: "d-id", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
        let bodyString = try location.toString()
        var lastCalledLocation: FloatLocation? = nil
        var lastCalledUser: UserRole? = nil
        let mock = LocationUsecaseMock(putHandler: { item, user in
            lastCalledLocation = item
            lastCalledUser = user
            return item
        })
        let subject = makeUsecase(mock)
        var request = makeRequest(method: .put, body: bodyString)
        request.user = nil

        
        let result = try await subject.put(request, next: next)

        
        #expect(lastCalledLocation == location)
        #expect(lastCalledUser == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let body = try FloatLocation.from(result.body)
        #expect(body == location)
    }

    @Test func test_put_異常() async throws {
        let location = FloatLocation(districtId: "d-id", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
        let bodyString = try location.toString()
        let expectedError = Error.internalServerError("put_failed")
        let mock = LocationUsecaseMock(putHandler: { _, _ in
            throw expectedError
        })
        let subject = makeUsecase(mock)
        let request = makeRequest(method: .put, user: .district("d-id"), body: bodyString)

        
        await #expect(throws: expectedError) {
            let _ = try await subject.put(request, next: next)
        }
    }

    @Test func test_delete_正常() async throws {
        var lastCalledId: String? = nil
        var lastCalledUser: UserRole? = nil
        let mock = LocationUsecaseMock(deleteHandler: { id, user in
            lastCalledId = id
            lastCalledUser = user
        })

        let subject = makeUsecase(mock)
        let request = makeRequest(method: .delete, parameters: ["districtId": "d-id"], user: .district("d-id"))

        
        let result = try await subject.delete(request, next: next)

        
        #expect(lastCalledId == "d-id")
        #expect(lastCalledUser == .district("d-id"))
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        #expect(mock.deleteCallCount == 1)
    }

    @Test func test_delete_userがnil() async throws {
        var lastCalledId: String? = nil
        var lastCalledUser: UserRole? = nil
        let mock = LocationUsecaseMock(deleteHandler: { id, user in
            lastCalledId = id
            lastCalledUser = user
        })

        let subject = makeUsecase(mock)
        var request = makeRequest(method: .delete, parameters: ["districtId": "d-id"]) 
        request.user = nil

        
        let result = try await subject.delete(request, next: next)

        
        #expect(lastCalledId == "d-id")
        #expect(lastCalledUser == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        #expect(mock.deleteCallCount == 1)
    }

    @Test func test_delete_異常() async throws {
        let expectedError = Error.notFound("指定された位置情報が見つかりません")
        let mock = LocationUsecaseMock(deleteHandler: { _, _ in throw expectedError })
        let subject = makeUsecase(mock)
        let request = makeRequest(method: .delete, parameters: ["districtId": "d-id"], user: .district("d-id"))

        
        await #expect(throws: expectedError) {
            let _ = try await subject.delete(request, next: next)
        }

        
        #expect(mock.deleteCallCount == 1)
    }

}

extension LocationControllerTest {
    private func makeUsecase(_ usecase: LocationUsecaseMock) -> LocationController {
        return withDependencies({ $0[LocationUsecaseKey.self] = usecase }) {
            LocationController()
        }
    }

    private func makeRequest(
        method: Application.Method,
        path: String = "",
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        user: UserRole? = .guest,
        body: String? = nil
    ) -> Request {
        return Request(method: method, path: path, headers: headers, parameters: parameters, user: user, body: body)
    }
}
