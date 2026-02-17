//
//  DistrictUsecaseTests.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

import Testing
import Dependencies
@testable import Backend
import Shared
import Foundation

struct DistrictUsecaseTests {
    // MARK: - get
    @Test func test_get_正常() async throws {
        // 準備
        let districtId = "g-id"
        let district = District.mock(id: districtId)
        let performances = [Performance.mock()]
        var lastCalledIds: (get: String?, perf: String?) = (nil, nil)
        let districtRepository = DistrictRepositoryMock(getHandler: { id in
            lastCalledIds.get = id
            return district
        })
        let performanceRepository = PerformanceRepositoryMock(queryHandler: { id in
            lastCalledIds.perf = id
            return performances
        })
        let subject = make(districtRepository: districtRepository, performanceRepository: performanceRepository)

        // 実行
        let result = try await subject.get(districtId)

        // 確認
        #expect(result.district == district)
        #expect(result.performances == performances)
        #expect(lastCalledIds == (districtId, districtId))
        #expect(districtRepository.getCallCount == 1)
        #expect(performanceRepository.queryCallCount == 1)
    }

    @Test func test_get_対象なし() async throws {
        // 準備
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in nil })
        let subject = make(districtRepository: districtRepository)

        // 実行・確認
        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            let _ = try await subject.get("g-id")
        }

        #expect(districtRepository.getCallCount == 1)
    }

    @Test func test_get_異常() async throws {
        // 準備
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in throw Error.internalServerError() })
        let subject = make(districtRepository: districtRepository)

        // 実行・確認
        await #expect(throws: Error.internalServerError()) {
            let _ = try await subject.get("g-id")
        }

        #expect(districtRepository.getCallCount == 1)
    }

    // MARK: - query
    @Test func test_query_正常() async throws {
        // 準備
        let expected = District.mock(id: "q-id")
        let districtRepository = DistrictRepositoryMock(queryHandler: { _ in [expected] })
        let subject = make(districtRepository: districtRepository)

        // 実行
        let result = try await subject.query(by: "f-id")

        // 確認
        #expect(result.count == 1)
        #expect(result.first?.id == expected.id)
        #expect(districtRepository.queryCallCount == 1)
    }

    @Test func test_query_異常() async throws {
        // 準備
        let districtRepository = DistrictRepositoryMock(queryHandler: { _ in throw Error.internalServerError("query_failed") })
        let subject = make(districtRepository: districtRepository)

        // 実行・確認
        await #expect(throws: Error.internalServerError("query_failed")) {
            let _ = try await subject.query(by: "f-id")
        }

        #expect(districtRepository.queryCallCount == 1)
    }

    // MARK: - post
    @Test func test_post_正常() async throws {
        // 準備
        let headquarterId = "festival_headquarter"
        let user = UserRole.headquarter(headquarterId)
        let districtName = "district"
        let email = "a@b.c"
        let festival = Festival.mock(id: headquarterId)
        var lastCalledFestivalId: String? = nil
        var lastCalledUsername: String? = nil
        var lastCalledEmail: String? = nil
        var lastCalledPost: District? = nil
        var lastCheckedDuplicate: String? = nil

        let festivalRepository = FestivalRepositoryMock(getHandler: { id in
            lastCalledFestivalId = id
            return festival
        })
        let authManager = AuthManagerMock(createHandler: { username, mail in
            lastCalledUsername = username
            lastCalledEmail = mail
            return .district(username)
        })
        let districtRepository = DistrictRepositoryMock(
            getHandler: { id in
                lastCheckedDuplicate = id
                return nil
            },
            postHandler: { item in
                lastCalledPost = item
                return item
            }
        )
        let subject = make(districtRepository: districtRepository, festivalRepository: festivalRepository, authManager: authManager)

        // 実行
        let result = try await subject.post(user: user, headquarterId: headquarterId, newDistrictName: districtName, email: email)

        // 確認
        #expect(result.district.id == lastCalledUsername)
        #expect(lastCalledFestivalId == headquarterId)
        #expect(lastCalledEmail == email)
        #expect(lastCalledPost?.id == lastCalledUsername)
        #expect(lastCheckedDuplicate == lastCalledUsername)
        #expect(districtRepository.postCallCount == 1)
        #expect(authManager.createCallCount == 1)
    }

    @Test func test_post_祭典が見つからない() async throws {
        // 準備
        let headquarterId = "h-id"
        let user = UserRole.headquarter(headquarterId)
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in nil })
        let festivalRepository = FestivalRepositoryMock(getHandler: { _ in nil })
        let subject = make(districtRepository: districtRepository, festivalRepository: festivalRepository)

        // 実行・確認
        await #expect(throws: Error.notFound("所属する祭典が見つかりません")) {
            let _ = try await subject.post(user: user, headquarterId: headquarterId, newDistrictName: "district", email: "a@b.c")
        }

        #expect(festivalRepository.getCallCount == 1)
        #expect(districtRepository.postCallCount == 0)
    }

    @Test func test_post_invite失敗() async throws {
        // 準備
        let headquarterId = "h-id"
        let user = UserRole.headquarter(headquarterId)
        let festival = Festival.mock(id: headquarterId)
        let festivalRepository = FestivalRepositoryMock(getHandler: { _ in festival })
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in nil })
        let authManager = AuthManagerMock(createHandler: { _, _ in throw Error.internalServerError("invite_failed") })
        let subject = make(districtRepository: districtRepository, festivalRepository: festivalRepository, authManager: authManager)

        // 実行・確認
        await #expect(throws: Error.internalServerError("invite_failed")) {
            let _ = try await subject.post(user: user, headquarterId: headquarterId, newDistrictName: "district", email: "a@b.c")
        }

        #expect(festivalRepository.getCallCount == 1)
        #expect(authManager.createCallCount == 1)
        #expect(districtRepository.postCallCount == 0)
    }

    // MARK: - put (District権限: DistrictPack)
    @Test func test_putDistrictPack_正常() async throws {
        // 準備
        let id = "d"
        let user: UserRole = .district(id)
        var lastGetId: String? = nil
        var lastPutArgs: (String?, District?) = (nil, nil)
        let current = District.mock(id: id)
        let incomingDistrict = {
            var d = current
            d.name = "updated"
            return d
        }()
        let pack = DistrictPack(district: incomingDistrict, performances: [])
        let districtRepository = DistrictRepositoryMock(
            getHandler: { got in lastGetId = got; return current },
            putHandler: { putId, item in lastPutArgs = (putId, item); return item }
        )
        let performanceRepository = PerformanceRepositoryMock(queryHandler: { _ in [] })
        let subject = make(districtRepository: districtRepository, performanceRepository: performanceRepository)

        // 実行
        let result = try await subject.put(id: id, item: pack, user: user)

        // 確認
        #expect(result.district.name == "updated")
        #expect(lastGetId == id)
        #expect(lastPutArgs.0 == id)
        #expect(lastPutArgs.1?.id == id)
        #expect(districtRepository.getCallCount == 1)
        #expect(districtRepository.putCallCount == 1)
        #expect(performanceRepository.queryCallCount == 1)
    }

    @Test func test_putDistrictPack_権限エラー() async throws {
        // 準備
        let id = "d"
        let user: UserRole = .headquarter("h")
        let pack = DistrictPack(district: District.mock(id: id), performances: [])
        let districtRepository = DistrictRepositoryMock()
        let subject = make(districtRepository: districtRepository)

        // 実行・確認
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.put(id: id, item: pack, user: user)
        }

        #expect(districtRepository.putCallCount == 0)
    }

    @Test func test_putDistrictPack_対象なし() async throws {
        // 準備
        let id = "d"
        let user: UserRole = .district(id)
        let pack = DistrictPack(district: District.mock(id: id), performances: [])
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in nil })
        let subject = make(districtRepository: districtRepository)

        // 実行・確認
        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            let _ = try await subject.put(id: id, item: pack, user: user)
        }

        #expect(districtRepository.getCallCount == 1)
        #expect(districtRepository.putCallCount == 0)
    }

    // MARK: - put (HQ権限: District)
    @Test func test_putHQ_正常() async throws {
        // 準備
        let id = "d"
        let hq = "q-id"
        let user: UserRole = .headquarter(hq)
        var lastGetId: String? = nil
        var lastPutArgs: (String?, District?) = (nil, nil)
        var current = District.mock(id: id)
        var incoming = current
        incoming.order = current.order + 1
        incoming.group = current.group
        incoming.isEditable = !current.isEditable
        let districtRepository = DistrictRepositoryMock(
            getHandler: { got in lastGetId = got; return current },
            putHandler: { putId, item in lastPutArgs = (putId, item); return item }
        )
        let subject = make(districtRepository: districtRepository)

        // 実行
        let result = try await subject.put(id: id, district: incoming, user: user)

        // 確認
        #expect(result.id == id)
        #expect(lastGetId == id)
        #expect(lastPutArgs.0 == id)
        #expect(districtRepository.getCallCount == 1)
        #expect(districtRepository.putCallCount == 1)
    }

    @Test func test_putHQ_権限エラー() async throws {
        // 準備
        let id = "d"
        let user: UserRole = .guest
        let districtRepository = DistrictRepositoryMock()
        let subject = make(districtRepository: districtRepository)

        // 実行・確認
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.put(id: id, district: District.mock(id: id), user: user)
        }

        #expect(districtRepository.putCallCount == 0)
    }

    @Test func test_putHQ_対象なし() async throws {
        // 準備
        let id = "d"
        let user: UserRole = .headquarter("h")
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in nil })
        let subject = make(districtRepository: districtRepository)

        // 実行・確認
        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            let _ = try await subject.put(id: id, district: District.mock(id: id), user: user)
        }

        #expect(districtRepository.getCallCount == 1)
        #expect(districtRepository.putCallCount == 0)
    }
}

extension DistrictUsecaseTests {
    func make(
        districtRepository: DistrictRepositoryMock = .init(),
        performanceRepository: PerformanceRepositoryMock = .init(),
        festivalRepository: FestivalRepositoryMock = .init(),
        authManager: AuthManagerMock = .init()
    ) -> DistrictUsecase {
        let subject = withDependencies {
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PerformanceRepositoryKey.self] = performanceRepository
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[AuthManagerFactoryKey.self] = { authManager }
        } operation: {
            DistrictUsecase()
        }
        return subject
    }
}
