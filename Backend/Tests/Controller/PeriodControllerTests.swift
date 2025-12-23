//
//  PeriodControllerTests.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/20.
//

import Foundation
import Testing
@testable import Backend
import Dependencies
import Shared

struct PeriodControllerTests {
    let next: Handler = { _ in
        throw TestError.unimplemented
    }
    let expectedHeaders: [String: String] = ["Content-Type": "application/json"]
    let period = Period(id: "p-id", festivalId: "f-id", date: SimpleDate(year: 2025, month: 12, day: 20), start: .init(hour: 9, minute: 0), end: .init(hour: 12, minute: 0))
    
    @Test func test_query_byYear_正常() async throws {
        let expected = [period]
        var lastCalled: (String, Int)?
        let mock = PeriodUsecaseMock(queryYearHandler: { festivalId, year in
            lastCalled = (festivalId, year)
            return expected
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id", "year": "2025"])

        
        let result = try await subject.query(request,next: next)

        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try [Period].from(result.body)
        #expect(target == expected)
        #expect(lastCalled?.0 == "f-id")
        #expect(lastCalled?.1 == 2025)
    }
    
    @Test func test_query_byYear_異常() async throws {
        let mock = PeriodUsecaseMock(queryYearHandler: { _,_  in
            throw TestError.intentional
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id", "year": "2025"])

        
        await #expect(throws: TestError.intentional) {
            let _ = try await subject.query(request,next: next)
        }
    }

    @Test func test_query_byFestival_正常() async throws {
        let expected = [period]
        var lastCalled: String?
        let mock = PeriodUsecaseMock(queryFestivalHandler: { festivalId in
           lastCalled = festivalId
            return expected
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id", "all": "true"])

        
        let result = try await subject.query(request,next: next)

        
        #expect(mock.queryFestivalCallCount == 1)
        #expect(lastCalled == "f-id")
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try [Period].from(result.body)
        #expect(target == expected)
    }
    
    @Test func test_query_byFestival_異常() async throws {
        let mock = PeriodUsecaseMock(queryFestivalHandler: { _ in
            throw TestError.intentional
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id", "all": "true"])

        
        await #expect(throws: TestError.intentional) {
            let _ = try await subject.query(request,next: next)
        }
    }

    @Test func test_query_latest_正常() async throws {
        let expected = [period]
        var lastCalled: String?
        let mock = PeriodUsecaseMock(queryLatestHandler: { festivalId in
            lastCalled = festivalId
            return expected
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"])

        
        let result = try await subject.query(request,next: next)

        
        #expect(mock.queryLatestCallCount == 1)
        #expect(lastCalled == "f-id")
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try [Period].from(result.body)
        #expect(target == expected)
    }
    
    @Test func test_query_latest_異常() async throws {
        let mock = PeriodUsecaseMock(queryLatestHandler: { _ in
            throw TestError.intentional
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"])

        
        await #expect(throws: TestError.intentional) {
            let _ = try await subject.query(request,next: next)
        }
    }

    @Test func test_get_正常() async throws {
        let mock = PeriodUsecaseMock(getHandler: { _ in period })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["id": "p-id"])

        
        let result = try await subject.get(request,next: next)

        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Period.from(result.body)
        #expect(target == period)
    }

    @Test func test_get_異常() async throws {
        let mock = PeriodUsecaseMock(getHandler: { _ in
            throw TestError.intentional
        })
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["id": "non-existent-id"])

        
        await #expect(throws: TestError.intentional) {
            let _ = try await subject.get(request,next: next)
        }
    }

    @Test func test_post_正常() async throws {
        let body = try period.toString()
        var lastCalled: (Period, UserRole)?
        let mock = PeriodUsecaseMock(postHandler: { p, user in
            lastCalled = (p, user)
            return period
        })
        let subject = make(mock)
        let request = makeRequest(method: .post, body: body)

        
        let result = try await subject.post(request,next: next)

        
        #expect(mock.postCallCount == 1)
        #expect(lastCalled?.0 == period)
        #expect(lastCalled?.1 == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Period.from(result.body)
        #expect(target == period)
    }

    @Test func test_post_異常() async throws {
        let body = try period.toString()
        let mock = PeriodUsecaseMock(postHandler: { _, _ in
            throw TestError.intentional
        })
        let subject = make(mock)
        let request = makeRequest(method: .post, body: body)

        
        await #expect(throws: TestError.intentional) {
            let _ = try await subject.post(request,next: next)
        }
    }

    @Test func test_put_正常() async throws {
        let body = try period.toString()
        var lastCalled: (String, Period, UserRole)?
        let mock = PeriodUsecaseMock(putHandler: { id, p, user in
            lastCalled = (id, p, user)
            return period
        })
        let subject = make(mock)
        let request = makeRequest(method: .put, parameters: ["id": "p-id"], body: body)

        
        let result = try await subject.put(request,next: next)

        
        #expect(mock.putCallCount == 1)
        #expect(lastCalled?.0 == "p-id")
        #expect(lastCalled?.1 == period)
        #expect(lastCalled?.2 == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Period.from(result.body)
        #expect(target == period)
    }

    @Test func test_put_異常() async throws {
        let body = try period.toString()
        let mock = PeriodUsecaseMock(putHandler: { _, _, _ in
            throw TestError.intentional
        })
        let subject = make(mock)
        let request = makeRequest(method: .put, parameters: ["id": "p-id"], body: body)

        await #expect(throws: TestError.intentional) {
            let _ = try await subject.put(request,next: next)
        }
    }

    @Test func test_delete_正常() async throws {
        let mock = PeriodUsecaseMock(deleteHandler: { _, _ in })
        let subject = make(mock)
        let request = makeRequest(method: .delete, parameters: ["id": "p-id"])

        let result = try await subject.delete(request,next: next)

        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
    }

    @Test func test_delete_異常() async throws {
        let mock = PeriodUsecaseMock(deleteHandler: { _, _ in
            throw Error.notFound("Period not found")
        })
        let subject = make(mock)
        let request = makeRequest(method: .delete, parameters: ["id": "non-existent-id"])

        await #expect(throws: Error.notFound("Period not found")) {
            let _ = try await subject.delete(request,next: next)
        }
    }
}

extension PeriodControllerTests {
    func make(_ usecase: PeriodUsecaseMock) -> PeriodController {
        let subject = withDependencies({
            $0[PeriodUsecaseKey.self] = usecase
        }) {
            PeriodController()
        }
        return subject
    }

    func makeRequest(
        method: Application.Method,
        path: String = "",
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        user: UserRole = .guest,
        body: String? = nil
    ) -> Request {
        return Request(method: method, path: path, headers: headers, parameters: parameters, user: user, body: body)
    }
}

