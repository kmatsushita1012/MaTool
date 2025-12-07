//
//  ProgramControllerTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Foundation
import Testing
@testable import Backend
import Dependencies
import Shared

struct ProgramControllerTest {
    let next: Handler = { _ in throw TestError.unimplemented }
    let expectedHeaders = ["Content-Type": "application/json"]
    let program = Program(festivalId: "f-id", year: 2025, periods: [])
    
    @Test
    func test_getLatest_正常() async throws {
        var lastCalledFestivalId: String? = nil
        let mock = ProgramUsecaseMock(
            getLatestHandler: { festivalId in
                lastCalledFestivalId = festivalId
                return program
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"])

        
        let result = try await subject.getLatest(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Program.from(result.body)
        #expect(target == program)
        #expect(mock.getLatestCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
    }
    
    @Test
    func test_getLatest_異常() async throws {
        let expectedError = Error.internalServerError("getLatest_failed")
        var lastCalledFestivalId: String? = nil
        let mock = ProgramUsecaseMock(
            getLatestHandler: { festivalId in
                lastCalledFestivalId = festivalId
                throw expectedError
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"])

        
        await #expect(throws: expectedError) {
            try await subject.getLatest(request: request, next: next)
        }
        
        
        #expect(mock.getLatestCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
    }
    
    @Test
    func test_getByYear_正常() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        let mock = ProgramUsecaseMock(
            getByYearHandler: { festivalId, year in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                return program
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id", "year": "2025"])

        
        let result = try await subject.get(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Program.from(result.body)
        #expect(target == program)
        #expect(mock.getByYearCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledYear == 2025)
    }
    
    @Test
    func test_getByYear_異常() async throws {
        let expectedError = Error.internalServerError("getByYear_failed")
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        let mock = ProgramUsecaseMock(
            getByYearHandler: { festivalId, year in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                throw expectedError
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id", "year": "2025"])

        
        await #expect(throws: expectedError) {
            try await subject.get(request: request, next: next)
        }
        
        
        #expect(mock.getByYearCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledYear == 2025)
    }
    
    @Test
    func test_query_正常() async throws {
        var lastCalledFestivalId: String? = nil
        let mock = ProgramUsecaseMock(
            queryHandler: { festivalId in
                lastCalledFestivalId = festivalId
                return [program]
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"])

        
        let result = try await subject.query(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try [Program].from(result.body)
        #expect(target == [program])
        #expect(mock.queryCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
    }
    
    @Test
    func test_query_異常() async throws {
        let expectedError = Error.internalServerError("query_failed")
        var lastCalledFestivalId: String? = nil
        let mock = ProgramUsecaseMock(
            queryHandler: { festivalId in
                lastCalledFestivalId = festivalId
                throw expectedError
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .get, parameters: ["festivalId": "f-id"])

        
        await #expect(throws: expectedError) {
            try await subject.query(request: request, next: next)
        }
        
        
        #expect(mock.queryCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
    }
    
    @Test
    func test_post_正常() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledProgram: Program? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            postHandler: { festivalId, program, user in
                lastCalledFestivalId = festivalId
                lastCalledProgram = program
                lastCalledUser = user
                return self.program
            }
        )
        let subject = make(mock)
        let body = try program.toString()
        let request = makeRequest(method: .post, parameters: ["festivalId": "f-id"], user: .headquarter("f-id"), body: body)

        
        let result = try await subject.post(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Program.from(result.body)
        #expect(target == program)
        #expect(mock.postCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledProgram == program)
        #expect(lastCalledUser == .headquarter("f-id"))
    }
    
    @Test
    func test_post_userがnil() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledProgram: Program? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            postHandler: { festivalId, program, user in
                lastCalledFestivalId = festivalId
                lastCalledProgram = program
                lastCalledUser = user
                return self.program
            }
        )
        let subject = make(mock)
        let body = try program.toString()
        let request = makeRequest(method: .post, parameters: ["festivalId": "f-id"], user: nil, body: body)

        
        let result = try await subject.post(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Program.from(result.body)
        #expect(target == program)
        #expect(mock.postCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledProgram == program)
        #expect(lastCalledUser == .guest)
    }
    
    @Test
    func test_post_異常() async throws {
        let expectedError = Error.internalServerError("post_failed")
        var lastCalledFestivalId: String? = nil
        var lastCalledProgram: Program? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            postHandler: { festivalId, program, user in
                lastCalledFestivalId = festivalId
                lastCalledProgram = program
                lastCalledUser = user
                throw expectedError
            }
        )
        let subject = make(mock)
        let body = try program.toString()
        let request = makeRequest(method: .post, parameters: ["festivalId": "f-id"], user: .headquarter("f-id"), body: body)

        
        await #expect(throws: expectedError) {
            try await subject.post(request: request, next: next)
        }
        
        #expect(mock.postCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledProgram == program)
        #expect(lastCalledUser == .headquarter("f-id"))
    }
    
    @Test
    func test_put_正常() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        var lastCalledProgram: Program? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            putHandler: { festivalId, year, program, user in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                lastCalledProgram = program
                lastCalledUser = user
                return self.program
            }
        )
        let subject = make(mock)
        let body = try program.toString()
        let request = makeRequest(method: .put, parameters: ["festivalId": "f-id", "year": "2025"], user: .headquarter("f-id"), body: body)

        
        let result = try await subject.put(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Program.from(result.body)
        #expect(target == program)
        #expect(mock.putCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledYear == 2025)
        #expect(lastCalledProgram == program)
        #expect(lastCalledUser == .headquarter("f-id"))
    }
    
    @Test
    func test_put_userがnil() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        var lastCalledProgram: Program? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            putHandler: { festivalId, year, program, user in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                lastCalledProgram = program
                lastCalledUser = user
                return self.program
            }
        )
        let subject = make(mock)
        let body = try program.toString()
        let request = makeRequest(method: .put, parameters: ["festivalId": "f-id", "year": "2025"], user: nil, body: body)

        
        let result = try await subject.put(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Program.from(result.body)
        #expect(target == program)
        #expect(mock.putCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledYear == 2025)
        #expect(lastCalledProgram == program)
        #expect(lastCalledUser == .guest)
    }
    
    @Test
    func test_put_異常() async throws {
        let expectedError = Error.internalServerError("put_failed")
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        var lastCalledProgram: Program? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            putHandler: { festivalId, year, program, user in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                lastCalledProgram = program
                lastCalledUser = user
                throw expectedError
            }
        )
        let subject = make(mock)
        let body = try program.toString()
        let request = makeRequest(method: .put, parameters: ["festivalId": "f-id", "year": "2025"], user: .headquarter("f-id"), body: body)
        

        await #expect(throws: expectedError) {
            try await subject.put(request:request, next: next)
        }
        #expect(mock.putCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledYear == 2025)
        #expect(lastCalledProgram == program)
        #expect(lastCalledUser == .headquarter("f-id"))
    }
    
    @Test
    func test_delete_正常() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            deleteHandler: { festivalId, year, user in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                lastCalledUser = user
                return ()
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .delete, parameters: ["festivalId": "f-id", "year": "2025"], user: .headquarter("f-id"))

        
        let result = try await subject.delete(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        #expect(mock.deleteCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledYear == 2025)
        #expect(lastCalledUser == .headquarter("f-id"))
    }
    
    @Test
    func test_delete_userがnil() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            deleteHandler: { festivalId, year, user in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                lastCalledUser = user
                return ()
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .delete, parameters: ["festivalId": "f-id", "year": "2025"], user: nil)

        
        let result = try await subject.delete(request: request, next: next)
        
        
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        #expect(mock.deleteCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledYear == 2025)
        #expect(lastCalledUser == .guest)
    }
    
    @Test
    func test_delete_異常() async throws {
        let expectedError = Error.internalServerError("delete_failed")
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        var lastCalledUser: UserRole? = nil
        let mock = ProgramUsecaseMock(
            deleteHandler: { festivalId, year, user in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                lastCalledUser = user
                throw expectedError
            }
        )
        let subject = make(mock)
        let request = makeRequest(method: .delete, parameters: ["festivalId": "f-id", "year": "2025"], user: .headquarter("f-id"))

        
        await #expect(throws: expectedError) {
            try await subject.delete(request: request, next: next)
        }
        
        
        #expect(mock.deleteCallCount == 1)
        #expect(lastCalledFestivalId == "f-id")
        #expect(lastCalledYear == 2025)
        #expect(lastCalledUser == .headquarter("f-id"))
    }
}

extension ProgramControllerTest {
    func make(_ usecase: ProgramUsecaseMock) -> ProgramController {
        withDependencies({ $0[ProgramUsecaseKey.self] = usecase }) {
            ProgramController()
        }
    }
    
    func makeRequest(
        method: Application.Method,
        path: String = "",
        parameters: [String: String] = [:],
        headers: [String: String] = [:],
        user: UserRole? = nil,
        body: String? = nil
    ) -> Request {
        var req = Request.make(method: method, path: path, headers: headers, parameters: parameters, body: body)
        req.user = user
        return req
    }
}
