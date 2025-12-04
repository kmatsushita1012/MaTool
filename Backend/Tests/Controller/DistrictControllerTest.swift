//
//  DistrictControllerTest.swift
//  matool-backend
//
//  Created by assistant on 2025/11/30.
//

import Foundation
import Testing
@testable import Backend
import Dependencies
import Shared


struct DistrictControllerTest {
    let next: Handler = { _ in
        throw TestError.unimplemented
    }
    let expectedHeaders: [String: String] = ["Content-Type": "application/json"]

    @Test func test_query_正常() async throws {
        let expected = [District(id: "d-id", name: "d-name", festivalId: "f-id", visibility: .all)]
        let mock = DistrictUsecaseMock(queryHandler: { _ in expected })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"])


        let result = try await subject.query(request, next: next)


        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try [District].from(result.body)
        #expect(target == expected)
    }

    @Test func test_query_異常() async throws {
        let expectedError = Error.internalServerError("query_failed")
        let mock = DistrictUsecaseMock(queryHandler: { _ in throw expectedError })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"])


        await #expect(throws: expectedError) {
            let _ = try await subject.query(request, next: next)
        }


        #expect(mock.queryCallCount == 1)
    }

    @Test func test_get_正常() async throws {
        let expected = District(id: "g-id", name: "g-name", festivalId: "f-id", visibility: .all)
        var lastCalledId: String? = nil
        let mock = DistrictUsecaseMock(getHandler: { id in
            lastCalledId = id
            return expected
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["districtId": "g-id"]) 


        let result = try await subject.get(request, next: next)


        #expect(lastCalledId == "g-id")
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try District.from(result.body)
        #expect(target == expected)
    }

    @Test func test_get_異常() async throws {
        let expectedError = Error.internalServerError("get_failed")
        let mock = DistrictUsecaseMock(getHandler: { _ in throw expectedError })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["districtId": "g-id"]) 


        await #expect(throws: expectedError) {
            let _ = try await subject.get(request, next: next)
        }


        #expect(mock.getCallCount == 1)
    }

    @Test func test_getTools_正常() async throws {
        let now = Date()
        let expected = DistrictTool(districtId: "district-id", districtName: "district-name", festivalId: "festival-id", festivalName: "festival-name", checkpoints: [], base: Coordinate(latitude: 1.0, longitude: 2.0), periods: [], hazardSections: [])
        var lastCalledId: String?
        var lastCalledUser: UserRole?
        let mock = DistrictUsecaseMock(getToolsHandler: { id, user in
            lastCalledId = id
            lastCalledUser = user
            return expected
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, path: "", parameters: ["districtId": "district-id"], user: .district("district-id"))


        let result = try await subject.getTools(request, next: next)


        #expect(lastCalledId == "district-id")
        #expect(lastCalledUser == .district("district-id"))
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try DistrictTool.from(result.body)
        #expect(target == expected)
    }

    @Test func test_getTools_異常() async throws {
        let expectedError = Error.internalServerError("getTools_failed")
        let mock = DistrictUsecaseMock(getToolsHandler: { _, _ in throw expectedError })
        let subject = make(mock)
        let request = makeRequest(method: .get, path: "", parameters: ["districtId": "district-id"], user: .district("district-id"))


        await #expect(throws: expectedError) {
            let _ = try await subject.getTools(request, next: next)
        }


        #expect(mock.getToolsCallCount == 1)
    }

    @Test func test_post_正常() async throws {
        let expected = District(id: "p-id", name: "p-name", festivalId: "f-id", visibility: .all)
        let dto = DistrictCreateDTO(name: "p-name", email: "a@b.c")
        let expectedBody: String = try dto.toString()
        let mock = DistrictUsecaseMock(postHandler: { user, headquarterId, name, email in
            return expected
        })
        let subject = make(mock)
        let request = makeRequest(method: .post, parameters: ["festivalId": "f-id"], user: .headquarter("f-id"), body: expectedBody)


        let result = try await subject.post(request, next: next)


        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try District.from(result.body)
        #expect(target == expected)
    }

    @Test func test_post_異常() async throws {
        let dto = DistrictCreateDTO(name: "p-name", email: "a@b.c")
        let expectedBody: String = try dto.toString()
        let expectedError = Error.internalServerError("post_failed")
        let mock = DistrictUsecaseMock(postHandler: { _, _, _, _ in throw expectedError })
        let subject = make(mock)
        let request = makeRequest(method: .post, parameters: ["festivalId": "f-id"], user: .headquarter("f-id"), body: expectedBody)


        await #expect(throws: expectedError) {
            let _ = try await subject.post(request, next: next)
        }


        #expect(mock.postCallCount == 1)
    }

    @Test func test_put_正常() async throws {
        let expected = District(id: "d", name: "updated", festivalId: "f", visibility: .all)
        let body: String = try expected.toString()
        var lastCalledId: String?
        var lastCalledBody: District?
        var lastCalledUser: UserRole?
        let mock = DistrictUsecaseMock(putHandler: { id, body, user in
            lastCalledId = id
            lastCalledBody = body
            lastCalledUser = user
            return expected
        })
        let subject = make(mock)
        let request = makeRequest(method: .put, parameters: ["districtId": "d"], user: .district("d"), body: body)


        let result = try await subject.put(request, next: next)


        #expect(lastCalledId == "d")
        #expect(lastCalledBody == expected)
        #expect(lastCalledUser == .district("d"))
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try District.from(result.body)
        #expect(target == expected)
    }

    @Test func test_put_異常() async throws {
        let item = District(id: "d", name: "updated", festivalId: "f", visibility: .all)
        let expectedBody: String = try item.toString()
        let expectedError = Error.internalServerError("put_failed")
        let mock = DistrictUsecaseMock(putHandler: { _, _, _ in throw expectedError })
        let subject = make(mock)
        let request = makeRequest(method: .put, parameters: ["districtId": "d"], user: .district("d"), body: expectedBody)


        await #expect(throws: expectedError) {
            let _ = try await subject.put(request, next: next)
        }


        #expect(mock.putCallCount == 1)
    }
}

extension DistrictControllerTest {
    private func make(_ usecase: DistrictUsecaseMock) -> DistrictController{
        let  subject = withDependencies({
            $0[DistrictUsecaseKey.self] = usecase
        }){
            DistrictController()
        }
        return subject
    }

    private func makeRequest(
        method: Application.Method,
        path: String = "",
        parameters: [String : String] = [:],
        headers: [String : String] = [:],
        user: UserRole = .guest,
        body: String? = nil,
    ) -> Request{
        return Request(method: method, path: path, headers: headers, parameters: parameters, user: user, body: body)
    }
}
