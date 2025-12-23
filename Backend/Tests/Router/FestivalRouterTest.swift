//
//  FestivalRouterTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

import Foundation
import Testing
import Dependencies
@testable import Backend
import Shared


struct FestivalRouterTest {
    let festival = Festival(id: "f-id", name: "f-name", subname: "subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0.0, longitude: 0.0))
    let error = Error.internalServerError("test-error")
    
    @Test("GET /festivals/:festivalId 正常")
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
    
    @Test("GET /festivals/:festivalId_異常")
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
        
    @Test("PUT /festivals/:festivalId 正常")
    func test_put_正常() async throws {
        let request: Request = .make(method: .put ,path: "/festivals/f-id", body: try festival.toString())
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
    
    @Test("PUT /festivals/:festivalId 異常")
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

        
    @Test("GET /festivals_正常")
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

    @Test("GET /festivals_異常")
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
}

// MARK: - Location
extension FestivalRouterTest {
    @Test("GET /festivals/:fetivalId/locations 正常")
    func test_locations_query_正常() async throws {
        let request: Request = .make(method: .get, path: "/festivals/f-id/locations")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["festivalId"] = "f-id"
            return expected
        }()

        let dto = FloatLocationGetDTO(districtId: "d-id", districtName: "d-name", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
        let response: Response = try .success([dto])

        var lastCalledRequest: Request?
        let mock = LocationControllerMock(queryHandler: { req, next in
            lastCalledRequest = req
            return response
        })

        let subject = make(locationController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result == response)
        #expect(mock.queryCallCount == 1)
    }


    @Test("GET /festivals/:festivalId/locations 異常")
    func test_locations_query_異常() async throws {
        let request: Request = .make(method: .get, path: "/festivals/f-id/locations")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["festivalId"] = "f-id"
            return expected
        }()

        var lastCalledRequest: Request?
        let mock = LocationControllerMock(queryHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(locationController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.queryCallCount == 1)
    }
}

extension FestivalRouterTest {
    func make(
        festivalController: FestivalControllerMock = .init(),
        districtController: DistrictControllerMock = .init(),
        locationController: LocationControllerMock = .init()) -> Application {
        let router = withDependencies({
            $0[FestivalControllerKey.self] = festivalController
            $0[DistrictControllerKey.self] = districtController
            $0[LocationControllerKey.self] = locationController
        }){
            FestivalRouter()
        }
        return Application{ router }
    }
}


