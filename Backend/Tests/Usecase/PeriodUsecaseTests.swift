//
//  PeriodUsecaseTests.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/07.
//

import Testing
import Dependencies
@testable import Backend
import Shared

struct PeriodUsecaseTests {
    
    @Test
    func test_get_正常() async throws {
        let expected = Period(id: "p-id", date: .init(year: 2025, month: 11, day: 2), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))
        var lastCalledId: String? = nil
        let repo = PeriodRepositoryMock(getHandler: { id in
            lastCalledId = id
            return expected
        })
        let usecase = make(repository: repo)
        
        
        let result = try await usecase.get(id: "p-id")
        
        
        #expect(repo.getCallCount == 1)
        #expect(lastCalledId == "p-id")
        #expect(result == expected)
    }
    
    @Test
    func test_get_異常_見つからない() async throws {
        let repo = PeriodRepositoryMock(getHandler: { _ in nil })
        let usecase = make(repository: repo)
        
        
        await #expect(throws: Error.notFound("指定された日程が取得できませんでした。")) {
            _ = try await usecase.get(id: "p-id")
        }
        
        
        #expect(repo.getCallCount == 1)
    }
    
    @Test
    func test_query_正常() async throws {
        let expected = [Period(id: "p-id", date: .init(year: 2025, month: 11, day: 2), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))]
        var lastCalledId: String? = nil
        let repo = PeriodRepositoryMock(queryByFestivalHandler: { id in
            lastCalledId = id
            return expected
        })
        let usecase = make(repository: repo)
        
        
        let result = try await usecase.query(by: "p-id")
        
        
        #expect(repo.queryByFestivalCallCount == 1)
        #expect(lastCalledId == "p-id")
        #expect(result == expected)
    }
    
    @Test
    func test_query_異常_見つからない() async throws {
        let repo = PeriodRepositoryMock(queryByFestivalHandler: { _ in throw TestError.intentional })
        let usecase = make(repository: repo)
        
        
        await #expect(throws: TestError.intentional) {
            _ = try await usecase.query(by: "f-id")
        }
        
        
        #expect(repo.queryByFestivalCallCount == 1)
    }
    
    @Test
    func test_query_byFestivalYear_正常() async throws {
        let expected = [Period(id: "p-id", date: .init(year: 2025, month: 7, day: 1), start: .init(hour: 9, minute: 0), end: .init(hour: 10, minute: 0))]
        var lastCalled: (String, Int)? = nil
        let repo = PeriodRepositoryMock(queryByYearHandler: { fid, year  in
            lastCalled = (fid, year)
            return expected
        })
        let usecase = make(repository: repo)
        
        
        let result = try await usecase.query(festivalId: "f-id", year: 2025)
        
        
        #expect(repo.queryByYearCallCount == 1)
        #expect(lastCalled?.0 == "f-id")
        #expect(lastCalled?.1 == 2025)
        #expect(result == expected)
    }
    
    @Test
    func test_query_byFestivalYear_異常() async throws {
        let repo = PeriodRepositoryMock(queryByYearHandler: { _,_  in throw TestError.intentional })
        let usecase = make(repository: repo)
        
        
        await #expect(throws: TestError.intentional) {
            _ = try await usecase.query(festivalId: "f1", year: 2025)
        }
        
        
        #expect(repo.queryByYearCallCount == 1)
    }
    
    @Test
    func test_query_byYear_正常() async throws {
        let expected = [Period(id: "p-id", date: .init(year: 2025, month: 8, day: 2), start: .init(hour: 13, minute: 0), end: .init(hour: 14, minute: 0))]
        var lastCalled: (String, Int)? = nil
        let repo = PeriodRepositoryMock(queryByYearHandler: { fid, year in
            lastCalled = (fid, year)
            return expected
        })
        let usecase = make(repository: repo)
        
        
        let result = try await usecase.query(festivalId: "p-id", year: 2025)
        
        
        #expect(repo.queryByYearCallCount == 1)
        let args = try #require(lastCalled)
        #expect(args.0 == "p-id")
        #expect(args.1 == 2025)
        #expect(result == expected)
    }
    
    @Test
    func test_query_byYear_異常_年が負() async throws {
        let repo = PeriodRepositoryMock()
        let usecase = make(repository: repo)
        
        
        await #expect(throws: Error.badRequest("年が正しくありません。")) {
            _ = try await usecase.query(festivalId: "f-id", year: -1)
        }
    }
    
    @Test
    func test_query_byYear_異常() async throws {
        let repo = PeriodRepositoryMock(queryByYearHandler: { _,_  in throw TestError.intentional })
        let usecase = make(repository: repo)
        
        
        await #expect(throws: TestError.intentional) {
            _ = try await usecase.query(festivalId: "f-id", year: 2025)
        }
        
        
        #expect(repo.queryByYearCallCount == 1)
    }
    
    @Test
    func test_queryLatest_正常() async throws {
        let expected = [Period(id: "pl1", date: .init(year: 2025, month: 9, day: 3), start: .init(hour: 15, minute: 0), end: .init(hour: 16, minute: 0))]
        var lastCalled: String? = nil
        let repo = PeriodRepositoryMock(queryByFestivalHandler: { fid in
            lastCalled = fid
            return expected
        })
        let usecase = make(repository: repo)
        
        
        let result = try await usecase.queryLatest(by: "f1")

        
        #expect(repo.queryByFestivalCallCount == 1)
        #expect(lastCalled == "f1")
        #expect(result == expected)
    }
    
    @Test
    func test_queryLatest_正常_存在しない() async throws {
        let repo = PeriodRepositoryMock(queryByFestivalHandler: { _ in [] })
        let usecase = make(repository: repo)


        let result = try await usecase.queryLatest(by: "f1")

        
        #expect(result == [])
    }

    @Test
    func test_queryLatest_異常() async throws {
        let repo = PeriodRepositoryMock(queryByFestivalHandler: { _ in throw TestError.intentional })
        let usecase = make(repository: repo)


        await #expect(throws: TestError.intentional) {
            _ = try await usecase.queryLatest(by: "f1")
        }


        #expect(repo.queryByFestivalCallCount == 1)
    }
    
    @Test
    func test_post_正常() async throws {
        let expected = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 5, day: 1), start: .init(hour: 9, minute: 0), end: .init(hour: 10, minute: 0))
        var lastCalled: Period? = nil
        let repo = PeriodRepositoryMock(postHandler: { period in
            lastCalled = period
            return period
        })
        let usecase = make(repository: repo)
        
        
        let user = UserRole.headquarter("hq-1")
        let result = try await usecase.post(period: expected, user: user)
        
        
        #expect(repo.postCallCount == 1)
        let args = try #require(lastCalled)
        #expect(args == expected)
        #expect(result == expected)
    }
    
    @Test
    func test_post_異常_festivalIdが異なる() async throws {
        let repo = PeriodRepositoryMock()
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 8, minute: 0), end: .init(hour: 9, minute: 0))
        let usecase = make(repository: repo)
        
        
        let user = UserRole.headquarter("hq-2")
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.post(period: period, user: user)
        }
        
        
        #expect(repo.postCallCount == 0)
    }
    
    @Test
    func test_post_異常_districtからのアクセス() async throws {
        let repo = PeriodRepositoryMock()
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 8, minute: 0), end: .init(hour: 9, minute: 0))
        let usecase = make(repository: repo)
        
        
        let user = UserRole.district("d-1")
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.post(period: period, user: user)
        }
        
        
        #expect(repo.postCallCount == 0)
    }
    
    @Test
    func test_post_異常_guestからのアクセス() async throws {
        let repo = PeriodRepositoryMock()
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 8, minute: 0), end: .init(hour: 9, minute: 0))
        let usecase = make(repository: repo)
        
        
        let user = UserRole.guest
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.post(period: period, user: user)
        }
        
        
        #expect(repo.postCallCount == 0)
    }
    
    @Test
    func test_post_異常() async throws {
        let repo = PeriodRepositoryMock(postHandler: { _ in throw TestError.intentional })
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 8, minute: 0), end: .init(hour: 9, minute: 0))
        let usecase = make(repository: repo)
        
        
        let user = UserRole.headquarter("hq-1")
        await #expect(throws: TestError.intentional) {
            _ = try await usecase.post(period: period, user: user)
        }
        
        
        #expect(repo.postCallCount == 1)
    }
    
    @Test
    func test_put_正常() async throws {
        let expected = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 10, day: 10), start: .init(hour: 9, minute: 0), end: .init(hour: 12, minute: 0))
        var lastCalled: Period? = nil
        let repo = PeriodRepositoryMock(putHandler: { item in
            lastCalled = item
            return item
        })
        let usecase = make(repository: repo)
        
        
        let user = UserRole.headquarter("hq-1")
        let result = try await usecase.put(id: "p-id", period: expected, user: user)
        
        
        #expect(repo.putCallCount == 1)
        #expect(lastCalled == expected)
        #expect(result == expected)
    }
    
    @Test
    func test_put_異常_headquarterIdが異なる() async throws {
        let repo = PeriodRepositoryMock(putHandler: { _ in throw TestError.intentional })
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 8, minute: 0), end: .init(hour: 9, minute: 0))
        let usecase = make(repository: repo)
        
        
        let user = UserRole.headquarter("hq-2")
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.put(id: "p-id", period: period, user: user)
        }
        
        
        #expect(repo.putCallCount == 0)
    }
    
    @Test
    func test_put_異常_districtからのアクセス() async throws {
        let repo = PeriodRepositoryMock()
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 8, minute: 0), end: .init(hour: 9, minute: 0))
        let usecase = make(repository: repo)
        
        
        let user = UserRole.district("d-1")
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.put(id: "p-id", period: period, user: user)
        }
        
        
        #expect(repo.putCallCount == 0)
    }
    
    @Test
    func test_put_異常_guestからのアクセス() async throws {
        let repo = PeriodRepositoryMock()
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 8, minute: 0), end: .init(hour: 9, minute: 0))
        let usecase = make(repository: repo)
        
        
        let user = UserRole.guest
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.put(id: "p-id", period: period, user: user)
        }
        
        
        #expect(repo.putCallCount == 0)
    }
    
    @Test
    func test_put_異常_idが異なる() async throws {
        let repo = PeriodRepositoryMock()
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 8, minute: 0), end: .init(hour: 9, minute: 0))
        let usecase = make(repository: repo)
        
        
        let user = UserRole.headquarter("hq-1")
        await #expect(throws: Error.badRequest("リクエストが不正です。")) {
            _ = try await usecase.put(id: "p-2", period: period, user: user)
        }
        
        
        #expect(repo.putCallCount == 0)
    }
    
    @Test
    func test_put_異常() async throws {
        let repo = PeriodRepositoryMock(putHandler: { _ in throw TestError.intentional })
        let usecase = make(repository: repo)
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 1, day: 1), start: .init(hour: 9, minute: 0), end: .init(hour: 10, minute: 0))
        
        
        let user = UserRole.headquarter("hq-1")
        await #expect(throws: TestError.intentional) {
            _ = try await usecase.put(id: "p-id", period: period, user: user)
        }
        
        
        #expect(repo.putCallCount == 1)
    }

    @Test
    func test_delete_正常() async throws {
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 11, day: 2), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))
        var lastCalledGetId: String? = nil
        var lastCalledDeleteId: String? = nil
        let repo = PeriodRepositoryMock(
            getHandler: { id in
                lastCalledGetId = id
                return period
            },
            deleteHandler: { id in lastCalledDeleteId = id }
        )
        let usecase = make(repository: repo)


        let user = UserRole.headquarter("hq-1")
        try await usecase.delete(id: "p-id", user: user)


        #expect(repo.deleteCallCount == 1)
        #expect(lastCalledGetId == "p-id")
        #expect(lastCalledDeleteId == "p-id")
    }
    
    @Test
    func test_delete_異常_headquarterIdが異なる() async throws {
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 11, day: 2), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))
        let repo = PeriodRepositoryMock(
            getHandler: { _ in return period }
        )
        let usecase = make(repository: repo)
        
        
        let user = UserRole.headquarter("hq-2")
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.delete(id: "p-id", user: user)
        }
        
        
        #expect(repo.getCallCount == 1)
        #expect(repo.deleteCallCount == 0)
    }
    
    @Test
    func test_delete_異常_districtからのアクセス() async throws {
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 11, day: 2), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))
        let repo = PeriodRepositoryMock(
            getHandler: { _ in period }
        )
        let usecase = make(repository: repo)
        
        
        let user = UserRole.district("d-1")
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.delete(id: "p-id", user: user)
        }
        
        
        #expect(repo.getCallCount == 1)
        #expect(repo.deleteCallCount == 0)
    }
    
    @Test
    func test_delete_異常_guestからのアクセス() async throws {
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 11, day: 2), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))
        let repo = PeriodRepositoryMock(
            getHandler: { _ in period }
        )
        let usecase = make(repository: repo)
        
        
        let user = UserRole.guest
        await #expect(throws: Error.unauthorized("アクセス権限がありません。")) {
            _ = try await usecase.delete(id: "p-id", user: user)
        }
        
        
        #expect(repo.getCallCount == 1)
        #expect(repo.deleteCallCount == 0)
    }
    
    @Test
    func test_delete_異常_見つからない() async throws {
        let repo = PeriodRepositoryMock(
            getHandler: { _ in return nil }
        )
        let usecase = make(repository: repo)
        let user = UserRole.headquarter("hq-1")
        
        
        await #expect(throws: Error.notFound("データが見つかりません。")) {
            try await usecase.delete(id: "p-id", user: user)
        }


        #expect(repo.getCallCount == 1)
        #expect(repo.deleteCallCount == 0)
    }

    @Test
    func test_delete_異常() async throws {
        let period = Period(id: "p-id", festivalId: "hq-1", date: .init(year: 2025, month: 11, day: 2), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))
        let repo = PeriodRepositoryMock(
            getHandler: { _ in period },
            deleteHandler: { _ in throw TestError.intentional },
        )
        let usecase = make(repository: repo)


        let user = UserRole.headquarter("hq-1")
        await #expect(throws: TestError.intentional) {
            try await usecase.delete(id: "p-id", user: user)
        }


        #expect(repo.getCallCount == 1)
        #expect(repo.deleteCallCount == 1)
    }
}

extension PeriodUsecaseTests {
    private func make(
        repository: PeriodRepositoryMock = .init()
    ) -> PeriodUsecase {
        withDependencies {
            $0[PeriodRepositoryKey.self] = repository
        } operation: {
            PeriodUsecase()
        }
    }
}
