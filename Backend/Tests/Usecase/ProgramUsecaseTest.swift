//
//  ProgramUsecaseTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Testing
import Dependencies
@testable import Backend
import Shared

struct ProgramUsecaseTests {
    let program = Program(festivalId: "fes_1", year: 2025, periods: [])
    let programs: [Program] = [
        Program(festivalId: "fes_1", year: 2024, periods: []),
        Program(festivalId: "fes_1", year: 2025, periods: [])
    ]

    @Test
    func test_get_正常() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        let repo = ProgramRepositoryMock(
            getHandler: { festivalId, year in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
                return self.program
            }
        )
        let subject = make(repository: repo)
        let result = try await subject.get(festivalId: "fes_1", year: 2025)

        #expect(result == program)
        #expect(repo.getCallCount == 1)
        #expect(lastCalledFestivalId == "fes_1")
        #expect(lastCalledYear == 2025)
    }

    @Test
    func test_get_異常_リポジトリエラー() async {
        let repo = ProgramRepositoryMock(
            getHandler: { _, _ in throw TestError.intentional }
        )
        let subject = make(repository: repo)
        await #expect(throws: TestError.intentional) {
            _ = try await subject.get(festivalId: "fes_1", year: 2025)
        }
    }

    @Test
    func test_get_異常_バリデーション() async {
        let repo = ProgramRepositoryMock(
            getHandler: { _, _ in self.program }
        )
        let subject = make(repository: repo)
        await #expect(throws: Error.badRequest("年が正しくありません。")) {
            _ = try await subject.get(festivalId: "fes_1", year: -1)
        }
    }

    @Test
    func test_query_正常() async throws {
        var lastCalledFestivalId: String? = nil
        let repo = ProgramRepositoryMock(
            queryHandler: { festivalId, _ in
                lastCalledFestivalId = festivalId
                return self.programs
            }
        )
        let subject = make(repository: repo)
        let result = try await subject.query(festivalId: "fes_1")

        #expect(result == programs)
        #expect(repo.queryCallCount == 1)
        #expect(lastCalledFestivalId == "fes_1")
    }

    @Test
    func test_query_異常_リポジトリエラー() async {
        let repo = ProgramRepositoryMock(
            queryHandler: { _, _ in throw TestError.intentional }
        )
        let subject = make(repository: repo)
        await #expect(throws: TestError.intentional) {
            _ = try await subject.query(festivalId: "fes_1")
        }
    }

    @Test
    func test_post_正常() async throws {
        var lastCalledProgram: Program? = nil
        let repo = ProgramRepositoryMock(
            postHandler: { program in
                lastCalledProgram = program
                return program
            }
        )
        let subject = make(repository: repo)
        let result = try await subject.post(festivalId: "fes_1", program: program, user: .headquarter("fes_1"))

        #expect(result == program)
        #expect(repo.postCallCount == 1)
        #expect(lastCalledProgram == program)
    }

    @Test
    func test_post_異常_リポジトリエラー() async {
        let repo = ProgramRepositoryMock(
            postHandler: { _ in throw TestError.intentional }
        )
        let subject = make(repository: repo)
        await #expect(throws: TestError.intentional) {
            _ = try await subject.post(festivalId: "fes_1", program: program, user: .headquarter("fes_1"))
        }
    }

    @Test
    func test_post_異常_権限() async {
        let repo = ProgramRepositoryMock(
            postHandler: { program in return program }
        )
        let subject = make(repository: repo)
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await subject.post(festivalId: "fes_1", program: program, user: .headquarter("other_fes"))
        }
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await subject.post(festivalId: "fes_1", program: program, user: .guest)
        }
    }

    @Test
    func test_put_正常() async throws {
        var lastCalledProgram: Program? = nil
        let repo = ProgramRepositoryMock(
            putHandler: { program in
                lastCalledProgram = program
                return program
            }
        )
        let subject = make(repository: repo)
        let result = try await subject.put(festivalId: "fes_1", year: 2025, program: program, user: .headquarter("fes_1"))

        #expect(result == program)
        #expect(repo.putCallCount == 1)
        #expect(lastCalledProgram == program)
    }

    @Test
    func test_put_異常_リポジトリエラー() async {
        let repo = ProgramRepositoryMock(
            putHandler: { _ in throw TestError.intentional }
        )
        let subject = make(repository: repo)
        await #expect(throws: TestError.intentional) {
            _ = try await subject.put(festivalId: "fes_1", year: 2025, program: program, user: .headquarter("fes_1"))
        }
    }

    @Test
    func test_put_異常_バリデーション() async {
        let repo = ProgramRepositoryMock(
            putHandler: { program in return program }
        )
        let subject = make(repository: repo)
        await #expect(throws: Error.badRequest("年が正しくありません。")) {
            _ = try await subject.put(festivalId: "fes_1", year: 0, program: program, user: .headquarter("fes_1"))
        }
    }

    @Test
    func test_put_異常_権限() async {
        let repo = ProgramRepositoryMock(
            putHandler: { program in return program }
        )
        let subject = make(repository: repo)
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await subject.put(festivalId: "fes_1", year: 2025, program: program, user: .headquarter("other_fes"))
        }
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await subject.put(festivalId: "fes_1", year: 2025, program: program, user: .guest)
        }
    }

    @Test
    func test_delete_正常() async throws {
        var lastCalledFestivalId: String? = nil
        var lastCalledYear: Int? = nil
        let repo = ProgramRepositoryMock(
            deleteHandler: { festivalId, year in
                lastCalledFestivalId = festivalId
                lastCalledYear = year
            }
        )
        let subject = make(repository: repo)
        try await subject.delete(festivalId: "fes_1", year: 2025, user: .headquarter("fes_1"))

        #expect(repo.deleteCallCount == 1)
        #expect(lastCalledFestivalId == "fes_1")
        #expect(lastCalledYear == 2025)
    }

    @Test
    func test_delete_異常_リポジトリエラー() async {
        let repo = ProgramRepositoryMock(
            deleteHandler: { _, _ in throw TestError.intentional }
        )
        let subject = make(repository: repo)
        await #expect(throws: TestError.intentional) {
            try await subject.delete(festivalId: "fes_1", year: 2025, user: .headquarter("fes_1"))
        }
    }

    @Test
    func test_delete_異常_権限() async {
        let repo = ProgramRepositoryMock(
            deleteHandler: { _, _ in }
        )
        let subject = make(repository: repo)
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            try await subject.delete(festivalId: "fes_1", year: 2025, user: .headquarter("other_fes"))
        }
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            try await subject.delete(festivalId: "fes_1", year: 2025, user: .guest)
        }
    }
}

extension ProgramUsecaseTests {
    func make(repository: ProgramRepositoryMock = .init()) -> ProgramUsecase {
        let subject = withDependencies({
            $0[ProgramRepositoryKey.self] = repository
        }){
            ProgramUsecase()
        }
        return subject
    }
}

