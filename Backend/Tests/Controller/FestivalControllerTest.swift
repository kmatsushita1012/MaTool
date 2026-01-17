//
//  FestivalControllerTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

import Testing
@testable import Backend
import Dependencies
import Shared

struct FestivalControllerTest {
    let next: Handler = { _ in
        throw TestError.unimplemented
    }
    let expectedHeaders: [String: String] = ["Content-Type": "application/json"]
    
    @Test func test_scan_正常() async throws {
        let expected = [Festival(id: "s-id", name: "s-name", subname: "s-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0.0, longitude: 0.0))]
        let mock = FestivalUsecaseMock(scanHandler: { expected })
        let subject = makeUsecase(mock)
        let request = makeRequest(method: .get)
        
        
        let result = try await subject.scan(request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try [Festival].from(result.body)
        #expect(target == expected)
        #expect(mock.scanCallCount == 1)
    }
    
    @Test func test_scan_異常() async throws {
        let expected = Error.internalServerError("scan_failed")
        let mock = FestivalUsecaseMock(scanHandler: { throw expected })
        let subject = makeUsecase(mock)
        let request = makeRequest(method: .get)
        
        
        await #expect(throws: expected) {
            let _ = try await subject.scan(request, next: next)
        }
        
        
        #expect(mock.scanCallCount == 1)
    }

    @Test func test_get_正常() async throws {
        let expected = FestivalPack(festival: Festival(id: "g-id", name: "g-name", subname: "g-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0.0, longitude: 0.0)), checkpoints: [], hazardSections: [])
        var lastCalledId: String? = nil
        let mock = FestivalUsecaseMock(getHandler: { id in
            lastCalledId = id
            return expected
        })
        let subject = makeUsecase(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "g-id"])
        
        
        let result = try await subject.get(request, next: next)
        
        
        #expect(lastCalledId == "g-id")
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Festival.from(result.body)
        #expect(target == expected)
        #expect(mock.getCallCount == 1)
    }

    @Test func test_get_異常() async throws {
        let expected = Error.internalServerError("get_failed")
        let mock = FestivalUsecaseMock(getHandler: { _ in throw expected })
        let subject = makeUsecase(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "g-id"]) 
        
        
        await #expect(throws: expected) {
            let _ = try await subject.get(request, next: next)
        }
        
        
        #expect(mock.getCallCount == 1)
    }
    
    @Test func test_put_正常() async throws {
        let expected = FestivalPack(festival: Festival(id: "g-id", name: "g-name", subname: "g-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0.0, longitude: 0.0)), checkpoints: [], hazardSections: [])
        var lastCalledItem: Festival? = nil
        var lastCalledUser: UserRole? = nil
        let mock = FestivalUsecaseMock(putHandler: { festival, user in
            lastCalledItem = festival
            lastCalledUser = user
            return expected
        })
        let subject = makeUsecase(mock)
        let request = Request(method: .put, path: "", headers: [:], parameters: [:], user: .headquarter("p-id"), body: try expected.toString())
        
        
        let result = try await subject.put(request, next: next)
        
        
        #expect(lastCalledItem == expected)
        #expect(lastCalledUser == .headquarter("p-id"))
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Festival.from(result.body)
        #expect(target == expected)
        #expect(mock.putCallCount == 1)
    }

    @Test func test_put_異常() async throws {
        let item = FestivalPack(festival: Festival(id: "g-id", name: "g-name", subname: "g-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0.0, longitude: 0.0)), checkpoints: [], hazardSections: [])
        let expectedBody: String = try item.toString()
        let expected = Error.internalServerError("put_failed")
        let mock = FestivalUsecaseMock(putHandler: { _, _ in throw expected })
        let subject = makeUsecase(mock)
        let request = Request(method: .put, path: "", headers: [:], parameters: [:], user: .headquarter("p-id"), body: expectedBody)
        
        
        await #expect(throws: expected) {
            let _ = try await subject.put(request, next: next)
        }
        
        
        #expect(mock.putCallCount == 1)
    }
}

extension FestivalControllerTest {
    private func makeUsecase(_ usecase: FestivalUsecaseMock) -> FestivalController{
        let  subject = withDependencies({
            $0[FestivalUsecaseKey.self] = usecase
        }){
            FestivalController()
        }
        return subject
    }
    
    private func makeRequest(
        method: Application.Method,
        path: String = "",
        parameters: [String : String] = [:],
        headers: [String : String] = [:],
        body: String? = nil

    ) -> Request{
        return Request(method: method, path: path, headers: headers, parameters: parameters, body: body)
    }
}
