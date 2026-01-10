//
//  PeriodRouterTests.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/20.
//

import Testing
import Dependencies
@testable import Backend
import Shared
import Foundation

struct PeriodRouterTests {
    let period = Period(id: "p-id", festivalId: "f-id", date: SimpleDate(year: 2025, month: 12, day: 20), start: .init(hour: 9, minute: 0), end: .init(hour: 12, minute: 0))
    let headers = ["Content-Type": "application/json"]
    let error = Error.internalServerError("test-error")

    @Test("GET /periods/:id 正常")
    func test_get_正常() async throws {
        let request: Request = .make(method: .get, path: "/periods/p-id")
        let expectedRequest: Request = { var expected = request; expected.parameters["id"] = "p-id"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(getHandler: { req, next in
            lastCalledRequest = req
            return try .success(self.period)
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(mock.getCallCount == 1)
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try Period.from(result.body)
        #expect(target == period)
        #expect(mock.getCallCount == 1)
    }

    @Test("GET /periods/:id 異常")
    func test_get_異常() async throws {
        let request: Request = .make(method: .get, path: "/periods/p-id")
        let expectedRequest: Request = { var expected = request; expected.parameters["id"] = "p-id"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(getHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(periodController: mock)

        let result = await subject.handle(request)

        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.getCallCount == 1)
    }
    
    @Test("GET /periods?festivalId=...&year=... 正常")
    func test_query_withYear_正常() async throws {
        let request: Request = .make(method: .get, path: "/periods", parameters: ["festivalId": "f-id", "year": "2025"])
        let expectedRequest: Request = { var expected = request; expected.parameters["festivalId"] = "f-id"; expected.parameters["year"] = "2025"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(queryHandler: { req, next in
            lastCalledRequest = req
            return try .success([self.period])
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(mock.queryCallCount == 1)
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try [Period].from(result.body)
        #expect(target == [period])
        #expect(mock.queryCallCount == 1)
    }

    @Test("GET /periods?festivalId=...&all=true 正常")
    func test_query_byFestival_正常() async throws {
        let request: Request = .make(method: .get, path: "/periods", parameters: ["festivalId": "f-id", "all": "true"])
        let expectedRequest: Request = { var expected = request; expected.parameters["festivalId"] = "f-id"; expected.parameters["all"] = "true"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(queryHandler: { req, next in
            lastCalledRequest = req
            return try .success([self.period])
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(mock.queryCallCount == 1)
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try [Period].from(result.body)
        #expect(target == [period])
        #expect(mock.queryCallCount == 1)
    }

    @Test("GET /periods?festivalId=... 正常")
    func test_query_latest_正常() async throws {
        let request: Request = .make(method: .get, path: "/periods", parameters: ["festivalId": "f-id"])
        let expectedRequest: Request = { var expected = request; expected.parameters["festivalId"] = "f-id"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(queryHandler: { req, next in
            lastCalledRequest = req
            return try .success([self.period])
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(mock.queryCallCount == 1)
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try [Period].from(result.body)
        #expect(target == [period])
        #expect(mock.queryCallCount == 1)
    }

    @Test("GET /periods 異常")
    func test_query_異常() async throws {
        let request: Request = .make(method: .get, path: "/periods", parameters: ["festivalId": "invalid"])
        let expectedRequest: Request = { var expected = request; expected.parameters["festivalId"] = "invalid"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(queryHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.queryCallCount == 1)
    }

    @Test("POST /periods 正常")
    func test_post_正常() async throws {
        let body = try period.toString()
        let request: Request = .make(method: .post, path: "/periods", body: body)
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(postHandler: { req, next in
            lastCalledRequest = req
            return try .success(self.period)
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(mock.postCallCount == 1)
        #expect(lastCalledRequest?.body == request.body)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try Period.from(result.body)
        #expect(target == period)
        #expect(mock.postCallCount == 1)
    }

    @Test("POST /periods 異常")
    func test_post_異常() async throws {
        let body = "invalid-body"
        let request: Request = .make(method: .post, path: "/periods", body: body)
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(postHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest?.body == request.body)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.postCallCount == 1)
    }

    @Test("PUT /periods/:id 正常")
    func test_put_正常() async throws {
        let body = try period.toString()
        let request: Request = .make(method: .put, path: "/periods/p-id", body: body)
        let expectedRequest: Request = { var expected = request; expected.parameters["id"] = "p-id"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(putHandler: { req, next in
            lastCalledRequest = req
            return try .success(self.period)
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(mock.putCallCount == 1)
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        let target = try Period.from(result.body)
        #expect(target == period)
        #expect(mock.putCallCount == 1)
    }

    @Test("PUT /periods/:id 異常")
    func test_put_異常() async throws {
        let body = "invalid-body"
        let request: Request = .make(method: .put, path: "/periods/p-id", body: body)
        let expectedRequest: Request = { var expected = request; expected.parameters["id"] = "p-id"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(putHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.putCallCount == 1)
    }

    @Test("DELETE /periods/:id 正常")
    func test_delete_正常() async throws {
        let request: Request = .make(method: .delete, path: "/periods/p-id")
        let expectedRequest: Request = { var expected = request; expected.parameters["id"] = "p-id"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(deleteHandler: { req, next in
            lastCalledRequest = req
            return try .success()
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)


        #expect(mock.deleteCallCount == 1)
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == 200)
        #expect(result.headers == headers)
        #expect(mock.deleteCallCount == 1)
    }

    @Test("DELETE /periods/:id 異常")
    func test_delete_異常() async throws {
        let request: Request = .make(method: .delete, path: "/periods/p-id")
        let expectedRequest: Request = { var expected = request; expected.parameters["id"] = "p-id"; return expected }()
        var lastCalledRequest: Request? = nil
        let mock = PeriodControllerMock(deleteHandler: { req, next in
            lastCalledRequest = req
            throw error
        })
        let subject = make(periodController: mock)

        
        let result = await subject.handle(request)

        
        #expect(lastCalledRequest == expectedRequest)
        #expect(result.statusCode == error.statusCode)
        #expect(mock.deleteCallCount == 1)
    }
}

extension PeriodRouterTests {
    func make(
        periodController: PeriodControllerMock = .init()
    ) -> Application {
        let router = withDependencies({
            $0[PeriodControllerKey.self] = periodController
        }){
            PeriodRouter()
        }
        return Application{ router }
    }
}

