//
//  FestivalRouterTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

import Testing
import Dependencies
@testable import Backend
import Shared

struct FestivalRouterTest {
    let festival = Festival(id: "g-id", name: "g-name", subname: "subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0.0, longitude: 0.0))
    let error = Error.internalServerError("test-error")
    
    @Test("test_get_/festivals/:festivalId_正常")
    func test_get_正常() async throws {
        let request: Request = .make(method: .get ,path: "/festivals/f-id")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["festivalId"] = "f-id"
            return expected
        }()
        let response: Response = try .success(festival)
        var lastCalledRequest: Request?
        let mock = FestivalControllerMock(getHandler: { req, next in
            lastCalledRequest = req
            return response
        })
        let subject = make(festivalController: mock)
        
        let result = await subject.handle(request)
        
        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result == response)
        #expect(mock.getCallCount == 1)
    }
    
    @Test("test_get_/festivals/:festivalId_異常")
    func test_get_異常() async throws {
        let request: Request = .make(method: .get ,path: "/festivals/f-id")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["festivalId"] = "f-id"
            return expected
        }()
        let response: Response = .error(error)
        var lastCalledRequest: Request?
        let mock = FestivalControllerMock(getHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(festivalController: mock)
        
        let result = await subject.handle(request)
        
        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == response.statusCode)
        #expect(mock.getCallCount == 1)
    }
    
    @Test("test_get_/festivals_正常")
    func test_scan_正常() async throws {
        let request: Request = .make(method: .get ,path: "/festivals")
        let response: Response = try .success([festival])
        var lastCalledRequest: Request?
        let mock = FestivalControllerMock(scanHandler: { req, next in
            lastCalledRequest = req
            return response
        })
        let subject = make(festivalController: mock)
        
        let result = await subject.handle(request)
        
        
        #expect(lastCalledRequest == request)
        #expect(result == response)
        #expect(mock.scanCallCount == 1)
    }
    
    @Test("test_get_/festivals_異常")
    func test_scan_異常() async throws {
        let request: Request = .make(method: .get ,path: "/festivals")
        let response: Response = .error(error)
        var lastCalledRequest: Request?
        let mock = FestivalControllerMock(scanHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(festivalController: mock)
        
        let result = await subject.handle(request)
        
        
        #expect(lastCalledRequest == request)
        #expect(result.statusCode == response.statusCode)
        #expect(mock.scanCallCount == 1)
    }
    
    @Test("test_put_/festivals_正常")
    func test_put_正常() async throws {
        let request: Request = .make(method: .put ,path: "/festivals", body: try festival.toString())
        let response: Response = try .success(festival)
        var lastCalledRequest: Request?
        let mock = FestivalControllerMock(putHandler: { req, next in
            lastCalledRequest = req
            return response
        })
        let subject = make(festivalController: mock)
        
        let result = await subject.handle(request)
        
        
        #expect(lastCalledRequest == request)
        #expect(result == response)
        #expect(mock.putCallCount == 1)
    }
    
    @Test("test_get_/festivals_異常")
    func test_put_異常() async throws {
        let request: Request = .make(method: .put ,path: "/festivals/f-id", body: try festival.toString())
        let response: Response = .error(error)
        var lastCalledRequest: Request?
        let mock = FestivalControllerMock(putHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(festivalController: mock)
        
        let result = await subject.handle(request)
        
        
        #expect(lastCalledRequest == request)
        #expect(result.statusCode == response.statusCode)
        #expect(mock.putCallCount == 1)
    }
}

extension FestivalRouterTest {
    func make(festivalController: FestivalControllerMock) -> Application {
        let router = withDependencies({
            $0[FestivalControllerKey.self] = festivalController
            $0[DistrictControllerKey.self] = DistrictControllerMock()
        }){
            FestivalRouter()
        }
        return Application{ router }
    }
}


