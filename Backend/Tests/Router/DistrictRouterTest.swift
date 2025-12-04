//
//  DistrictRouterTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/02.
//

import Testing
import Dependencies
@testable import Backend
import Shared
import Foundation

struct DistrictRouterTest {
    let location = FloatLocation(districtId: "d-id", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
    let locationDTO = FloatLocationGetDTO(districtId: "d-id", districtName: "d-name", coordinate: Coordinate(latitude: 0.0, longitude: 0.0), timestamp: Date(timeIntervalSince1970: 0))
    let item: RouteItem
    let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
    let currentResponse: CurrentResponse
    let district = District(id: "d-id", name: "d-name", festivalId: "f-id", visibility: .all)
    let tool = DistrictTool(districtId: "d-id", districtName: "d-name", festivalId: "f-id", festivalName: "f-name", checkpoints: [], base: Coordinate(latitude: 0.0, longitude: 0.0), spans: [])
    let error = Error.internalServerError("test-error")
    let headers = ["Content-Type": "application/json"]
    
    init() {
        item = .init(from: route)
        currentResponse = .init(districtId: "d-id", districtName: "d-name", routes: [item], current: route, location: nil)
        
    }

    @Test("GET /districts/:districtId/routes/current 正常")
    func test_getCurrent_正常() async throws {
        
        let request: Request = .make(method: .get, path: "/districts/d-id/routes/current")
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = RouteControllerMock(getCurrentHandler: { req, next in
            lastCalledRequest = req
            return try .success(currentResponse) }
        )
        let subject = make(routeController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try CurrentResponse.from(result.body)
        #expect(target == currentResponse)
        #expect(mock.getCurrentCallCount == 1)
    }

    @Test("GET /districts/:districtId/routes/current 異常")
    func test_getCurrent_異常() async throws {
        let request: Request = .make(method: .get, path: "/districts/d-id/routes/current")
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        var lastCalledRequest: Request? = nil
        let mock = RouteControllerMock(getCurrentHandler: { req, next in lastCalledRequest = req; throw error })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.getCurrentCallCount == 1)
    }

    @Test("GET /districts/:districtId/routes 正常")
    func test_routes_query_正常() async throws {
        let response: Response = try .success([item])

        let request: Request = .make(method: .get, path: "/districts/d-id/routes")
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        var lastCalledRequest: Request? = nil
        let mock = RouteControllerMock(queryHandler: { req, next in lastCalledRequest = req; return response })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try [RouteItem].from(result.body)
        #expect(target == [item])
        #expect(mock.queryCallCount == 1)
    }

    @Test("GET /districts/:districtId/routes 異常")
    func test_routes_query_異常() async throws {
        let request: Request = .make(method: .get, path: "/districts/d-id/routes")
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        var lastCalledRequest: Request? = nil
        let mock = RouteControllerMock(queryHandler: { req, next in lastCalledRequest = req; throw error })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.queryCallCount == 1)
    }

    @Test("POST /districts/:districtId/routes 正常")
    func test_routes_post_正常() async throws {
        let body = try route.toString()
        let request: Request = .make(method: .post, path: "/districts/d-id/routes", body: body)
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        let response: Response = try .success(route)
        var lastCalledRequest: Request? = nil
        let mock = RouteControllerMock(postHandler: { req, next in lastCalledRequest = req; return response })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try Route.from(result.body)
        #expect(target == route)
        #expect(mock.postCallCount == 1)
    }

    @Test("POST /districts/:districtId/routes 異常")
    func test_routes_post_異常() async throws {
        let body = try route.toString()
        let request: Request = .make(method: .post, path: "/districts/d-id/routes", body: body)
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        var lastCalledRequest: Request? = nil
        let mock = RouteControllerMock(postHandler: { req, next in lastCalledRequest = req; throw error })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.postCallCount == 1)
    }

    @Test("GET /districts/:districtId/tools 正常")
    func test_getTools_正常() async throws {
        let request: Request = .make(method: .get, path: "/districts/d-id/tools")
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        let response: Response = try .success(tool)

        var lastCalledRequest: Request? = nil
        let mock = DistrictControllerMock(getToolsHandler: { req, next in lastCalledRequest = req; return response })

        let subject = make(districtController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try DistrictTool.from(result.body)
        #expect(target == tool)
        #expect(mock.getToolsCallCount == 1)
    }

    @Test("GET /districts/:districtId/tools 異常")
    func test_getTools_異常() async throws {
        let request: Request = .make(method: .get, path: "/districts/d-id/tools")
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        var lastCalledRequest: Request? = nil
        let mock = DistrictControllerMock(getToolsHandler: { req, next in lastCalledRequest = req; throw error })

        let subject = make(districtController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.getToolsCallCount == 1)
    }
    
    @Test("GET /districts/:districtId/locations 正常")
    func test_locations_get_正常() async throws {
        let request: Request = .make(method: .get, path: "/districts/d-id/locations")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["districtId"] = "d-id"
            return expected
        }()

        let response: Response = try .success(locationDTO)
        var lastCalledRequest: Request? = nil
        let mock = LocationControllerMock(getHandler: { req, next in
            lastCalledRequest = req
            return response
        })

        let subject = make(locationController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try FloatLocationGetDTO.from(result.body)
        #expect(target == locationDTO)
        #expect(mock.getCallCount == 1)
    }

    @Test("GET /districts/:districtId/locations 異常")
    func test_locations_get_異常() async throws {
        let request: Request = .make(method: .get, path: "/districts/d-id/locations")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["districtId"] = "d-id"
            return expected
        }()

        var lastCalledRequest: Request? = nil
        let mock = LocationControllerMock(getHandler: { req, next in
            lastCalledRequest = req
            throw error
        })

        let subject = make(locationController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.getCallCount == 1)
    }

    @Test("PUT /districts/:districtId/locations 正常")
    func test_locations_put_正常() async throws {
        let body = try location.toString()
        let request: Request = .make(method: .put, path: "/districts/d-id/locations", body: body)
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["districtId"] = "d-id"
            return expected
        }()

        let response: Response = try .success(location)
        var lastCalledRequest: Request? = nil
        let mock = LocationControllerMock(putHandler: { req, next in
            lastCalledRequest = req
            return response
        })
        let subject = make(locationController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try FloatLocation.from(result.body)
        #expect(target == location)
        #expect(mock.putCallCount == 1)
    }

    @Test("PUT /districts/:districtId/locations 異常")
    func test_locations_put_異常() async throws {
        let body = try location.toString()
        let request: Request = .make(method: .put, path: "/districts/d-id/locations", body: body)
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["districtId"] = "d-id"
            return expected
        }()
        var lastCalledRequest: Request? = nil
        let mock = LocationControllerMock(putHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(locationController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.putCallCount == 1)
    }

    @Test("DELETE /districts/:districtId/locations 正常")
    func test_locations_delete_正常() async throws {
        let request: Request = .make(method: .delete, path: "/districts/d-id/locations")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["districtId"] = "d-id"
            return expected
        }()

        let response: Response = try .success()
        var lastCalledRequest: Request? = nil
        let mock = LocationControllerMock(deleteHandler: { req, next in
            lastCalledRequest = req
            return response
        })

        let subject = make(locationController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        #expect(mock.deleteCallCount == 1)
    }

    @Test("DELETE /districts/:districtId/locations 異常")
    func test_locations_delete_異常() async throws {
        let request: Request = .make(method: .delete, path: "/districts/d-id/locations")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["districtId"] = "d-id"
            return expected
        }()

        var lastCalledRequest: Request? = nil
        let mock = LocationControllerMock(deleteHandler: { req, next in
            lastCalledRequest = req
            throw error
        })

        let subject = make(locationController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.deleteCallCount == 1)
    }

    @Test("GET /districts/:districtId 正常")
    func test_district_get_正常() async throws {
        let request: Request = .make(method: .get, path: "/districts/d-id")
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        let response: Response = try .success(district)
        var lastCalledRequest: Request? = nil
        let mock = DistrictControllerMock(getHandler: { req, next in lastCalledRequest = req; return response })

        let subject = make(districtController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try District.from(result.body)
        #expect(target == district)
        #expect(mock.getCallCount == 1)
    }

    @Test("GET /districts/:districtId 異常")
    func test_district_get_異常() async throws {
        let request: Request = .make(method: .get, path: "/districts/d-id")
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        var lastCalledRequest: Request? = nil
        let mock = DistrictControllerMock(getHandler: { req, next in lastCalledRequest = req; throw error })

        let subject = make(districtController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.getCallCount == 1)
    }

    @Test("PUT /districts/:districtId 正常")
    func test_district_put_正常() async throws {
        let body = try district.toString()
        let request: Request = .make(method: .put, path: "/districts/d-id", body: body)
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        let response: Response = try .success(district)
        var lastCalledRequest: Request? = nil
        let mock = DistrictControllerMock(putHandler: { req, next in lastCalledRequest = req; return response })

        let subject = make(districtController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try District.from(result.body)
        #expect(target == district)
        #expect(mock.putCallCount == 1)
    }

    @Test("PUT /districts/:districtId 異常")
    func test_district_put_異常() async throws {
        let body = try district.toString()
        let request: Request = .make(method: .put, path: "/districts/d-id", body: body)
        let expectedRequest: Request = { var expected = request; expected.parameters["districtId"] = "d-id"; return expected }()

        var lastCalledRequest: Request? = nil
        let mock = DistrictControllerMock(putHandler: { req, next in lastCalledRequest = req; throw error })

        let subject = make(districtController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.putCallCount == 1)
    }
}

extension DistrictRouterTest {
    func make(
        districtController: DistrictControllerMock = .init(),
        routeController: RouteControllerMock = .init(),
        locationController: LocationControllerMock = .init()
    ) -> Application {
        let router = withDependencies({
            $0[DistrictControllerKey.self] = districtController
            $0[RouteControllerKey.self] = routeController
            $0[LocationControllerKey.self] = locationController
        }){
            DistrictRouter()
        }
        return Application{ router }
    }
}
