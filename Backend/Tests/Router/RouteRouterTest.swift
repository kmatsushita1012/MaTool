//
//  RouteRouterTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/02.
//

import Foundation
import Testing
import Dependencies
@testable import Backend
import Shared

struct RouteRouterTest {
    let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
    let error = Error.internalServerError("test-error")

    @Test("GET /routes/:routeId 正常")
    func test_get_正常() async throws {
        let request: Request = .make(method: .get, path: "/routes/r-id")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["routeId"] = "r-id"
            return expected
        }()

        let response: Response = try .success(route)

        var lastCalledRequest: Request?
        let mock = RouteControllerMock(getHandler: { req, next in
            lastCalledRequest = req
            return response
        })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result == response)
        #expect(mock.getCallCount == 1)
    }

    @Test("GET /routes/:routeId 異常")
    func test_get_異常() async throws {
        let request: Request = .make(method: .get, path: "/routes/r-id")
        let expectedRequest: Request = {
            var expected = request
            expected.parameters["routeId"] = "r-id"
            return expected
        }()

        var lastCalledRequest: Request?
        let mock = RouteControllerMock(getHandler: { req, next in
            lastCalledRequest = req
            throw error
        })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.getCallCount == 1)
    }

    @Test("PUT /routes/:routeId 正常")
    func test_put_正常() async throws {
        let request: Request = .make(method: .put,
                                     path: "/routes/r-id",
                                     body: try route.toString())
        let expectedRequest: Request = { var expected = request; expected.parameters["routeId"] = "r-id"; return expected }()
        let response: Response = try .success(route)
        var lastCalledRequest: Request?

        let mock = RouteControllerMock(putHandler: { req, next in
            lastCalledRequest = req
            return response
        })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result == response)
        #expect(mock.putCallCount == 1)
    }

    @Test("PUT /routes/:routeId 異常")
    func test_put_異常() async throws {
        let request: Request = .make(method: .put, path: "/routes/r-id",body: try route.toString())
        var lastCalledRequest: Request?
        let expectedRequest: Request = { var expected = request; expected.parameters["routeId"] = "r-id"; return expected }()
        let mock = RouteControllerMock(putHandler: { req, next in
            lastCalledRequest = req
            throw error
        })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.putCallCount == 1)
    }

    @Test("DELETE /routes/:routeId 正常")
    func test_delete_正常() async throws {
        let request: Request = .make(method: .delete, path: "/routes/r-id")
        let expectedRequest: Request = { var expected = request; expected.parameters["routeId"] = "r-id"; return expected }()
        let response: Response = try .success(route)
        var lastCalledRequest: Request?
        let mock = RouteControllerMock(deleteHandler: { req, next in
            lastCalledRequest = req
            return response
        })
        let subject = make(routeController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result == response)
        #expect(mock.deleteCallCount == 1)
    }

    @Test("DELETE /routes/:routeId 異常")
    func test_delete_異常() async throws {
        let request: Request = .make(method: .delete, path: "/routes/r-id")
        let expectedRequest: Request = { var expected = request; expected.parameters["routeId"] = "r-id"; return expected }()
        var lastCalledRequest: Request?
        let mock = RouteControllerMock(deleteHandler: { req, next in
            lastCalledRequest = req
            throw error
        })

        let subject = make(routeController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.deleteCallCount == 1)
    }

    @Test("GET /routes 正常")
    func test_getIds_正常() async throws {
        let request: Request = .make(method: .get, path: "/routes")
        let response: Response = try .success([route])

        var lastCalledRequest: Request?

        let mock = RouteControllerMock(getIdsHandler: { req, next in
            lastCalledRequest = req
            return response
        })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == request)
        #expect(result == response)
        #expect(mock.getIdsCallCount == 1)
    }

    @Test("GET /routes 異常")
    func test_getIds_異常() async throws {
        let request: Request = .make(method: .get, path: "/routes")

        var lastCalledRequest: Request?

        let mock = RouteControllerMock(getIdsHandler: { req, next in
            lastCalledRequest = req
            throw error
        })

        let subject = make(routeController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == request)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.getIdsCallCount == 1)
    }
}

extension RouteRouterTest {
    func make(routeController: RouteControllerMock) -> Application {
        let router = withDependencies({
            $0[RouteControllerKey.self] = routeController
        }) {
            RouteRouter()
        }

        return Application { router }
    }
}
