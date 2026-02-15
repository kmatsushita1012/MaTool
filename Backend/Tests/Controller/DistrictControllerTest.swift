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
