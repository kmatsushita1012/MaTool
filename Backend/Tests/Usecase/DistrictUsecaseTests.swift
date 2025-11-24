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

struct DistrictUsecaseTests{
    @Test func test_get_正常() async throws {
        let expected = District(id: "g-id", name: "g-name", festivalId: "festivalId", visibility: .all)
        var lastGetId: String? = nil
        let mock = DistrictRepositoryMock(
            getHandler: { id in
                lastGetId = id
                return expected
            }
        )
        let subject = make(mock)
        
        
        let result = try await subject.get("g-id")
        
        
        #expect(result == expected)
        #expect(lastGetId == "g-id")
        #expect(mock.getCallCount == 1)
    }
    
    @Test func test_get_対象なし() async throws {
        var lastGetId: String? = nil
        let mock = DistrictRepositoryMock(
            getHandler: { id in
                lastGetId = id
                return nil
            }
        )
        let subject = make(mock)
        
        
        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            let _ = try await subject.get("g-id")
        }

        
        #expect(lastGetId == "g-id")
        #expect(mock.getCallCount == 1)
    }
    
    @Test func test_get_異常() async throws {
        var lastGetId: String? = nil
        let mock = DistrictRepositoryMock(
            getHandler: { id in
                lastGetId = id
                throw Error.internalServerError()
            }
        )
        let subject = make(mock)
        
        
        await #expect(throws: Error.internalServerError()) {
            let _ = try await subject.get("g-id")
        }

        
        #expect(lastGetId == "g-id")
        #expect(mock.getCallCount == 1)
    }

    @Test func test_query_正常() async throws {
        let expected = District(id: "q-id", name: "q-name", festivalId: "f-id", visibility: .all)
        let mock = DistrictRepositoryMock(queryHandler: { festivalId in
            return [expected]
        })
        let subject = make(mock)


        let result = try await subject.query(by: "f-id")


        #expect(result.count == 1)
        #expect(result.first?.id == "q-id")
        #expect(mock.queryCallCount == 1)
    }
    
    @Test func test_query_異常() async throws {
        let mock = DistrictRepositoryMock(queryHandler: { _ in
            throw Error.internalServerError("query_failed")
        })
        let subject = make(mock)


        await #expect(throws: Error.internalServerError("query_failed")) {
            let _ = try await subject.query(by: "f-id")
        }


        #expect(mock.queryCallCount == 1)
    }

    @Test func test_post_正常() async throws {
        let headquarterId = "festival_headquarter"
        let user = UserRole.headquarter(headquarterId)
        let districtName = "district"
        let districtId = "festival_district"
        let email = "a@b.c"
        let district = District(id: "festival_district", name: "district", festivalId: "festival_headquarter", visibility: .all)
        let festival = Festival(id: headquarterId, name: "headquarter", subname: "subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0.0, longitude: 0.0))
        
        var lastCalledFestivalId: String? = nil
        let festivalRepositoryMock = FestivalRepositoryMock(
            getHandler: { item in
                lastCalledFestivalId = item
                return festival
            }
        )
        var lastCalledUsername: String? = nil
        var lastCalledEmail: String? = nil
        let authManagerMock = AuthManagerMock(createHandler: { username, email in
            lastCalledUsername = username
            lastCalledEmail = email
            return .district(username)
        })
        var lastCalledDistrictId: String? = nil
        var lastCalledDistrict: District? = nil
        let districtRepositoryMock = DistrictRepositoryMock(
            getHandler: { id in
                lastCalledDistrictId = id
                return nil
            }, postHandler: { item in
                lastCalledDistrict = item
                return item
            }
        )
        let subject = make(districtRepositoryMock, festivalRepository: festivalRepositoryMock, authManager: authManagerMock)


        let result = try await subject.post(user: user, headquarterId: headquarterId, newDistrictName: districtName, email: email)


        #expect(result == district)
        #expect(lastCalledUsername == districtId)
        #expect(lastCalledEmail == email)
        #expect(lastCalledDistrict == district)
        #expect(lastCalledDistrictId == district.id)
        #expect(lastCalledFestivalId == headquarterId)
        #expect(districtRepositoryMock.postCallCount == 1)
        #expect(authManagerMock.createCallCount == 1)
    }
    
    @Test func test_post_祭典が見つからない() async throws {
        let headquarterId = "h-id"
        let user = UserRole.headquarter(headquarterId)
        let districtName = "district"
        let email = "a@b.c"

        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in
            return nil
        })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in nil })
        let authManagerMock = AuthManagerMock()
        let subject = make(districtRepositoryMock, festivalRepository: festivalRepositoryMock, authManager: authManagerMock)


        await #expect(throws: Error.notFound("所属する祭典が見つかりません")) {
            let _ = try await subject.post(user: user, headquarterId: headquarterId, newDistrictName: districtName, email: email)
        }


        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.postCallCount == 0)
        #expect(authManagerMock.createCallCount == 0)
    }

    @Test func test_post_invite失敗() async throws {
        let headquarterId = "h-id"
        let user = UserRole.headquarter(headquarterId)
        let districtName = "district"
        let email = "a@b.c"
        let festival = Festival(id: headquarterId, name: "f", subname: "s", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0))

        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in festival })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in nil })
        let authManagerMock = AuthManagerMock(createHandler: { _, _ in throw Error.internalServerError("invite_failed") })
        let subject = make(districtRepositoryMock, festivalRepository: festivalRepositoryMock, authManager: authManagerMock)


        await #expect(throws: Error.internalServerError("invite_failed")) {
            let _ = try await subject.post(user: user, headquarterId: headquarterId, newDistrictName: districtName, email: email)
        }


        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(authManagerMock.createCallCount == 1)
        #expect(districtRepositoryMock.postCallCount == 0)
    }

    @Test func test_put_正常() async throws {
        var putCalled = false
        let mock = DistrictRepositoryMock(
            getHandler: { id in .init(id: "d", name: "n", festivalId: "f", visibility: .all) },
            putHandler: { id, item in
                putCalled = true
                return item
            }
        )
        let subject = make(mock)


        let item = District(id: "d", name: "updated", festivalId: "f", visibility: .all)
        let res = try await subject.put(id: "d", item: item, user: .district("d"))


        #expect(res.name == "updated")
        #expect(putCalled == true)
        #expect(mock.putCallCount == 1)
    }
    
    @Test func test_put_権限エラー() async throws {
        let mock = DistrictRepositoryMock()
        let subject = make(mock)

        let item = District(id: "d", name: "n", festivalId: "f", visibility: .all)


        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.put(id: "d", item: item, user: .headquarter("h-id"))
        }


        #expect(mock.putCallCount == 0)
    }

    @Test func test_getTools_正常() async throws {
        let now = Date()
        let district = District(id: "district-id", name: "district-name", festivalId: "festival-id", visibility: .all)
        let festival = Festival(id: "festival-id", name: "festival-name", subname: "festival-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 1.23, longitude: 4.56), spans: [Span(id: "s-id", start: now, end: now)])
        let tool = DistrictTool(districtId: "district-id", districtName: "district-name", festivalId: "festival-id", festivalName: "festival-name", milestones: [], base: Coordinate(latitude: 1.23, longitude: 4.56), spans: [Span(id: "s-id", start: now, end: now)])
        
        var lastCalledDistrictId: String? = nil
        var lastCalledFestivalId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(
            getHandler: { id in
                lastCalledDistrictId = id
                return district
            }
        )
        let festivalRepositoryMock = FestivalRepositoryMock(
            getHandler: { id in
                lastCalledFestivalId = id
                return festival
            }
        )
        let subject = make(
            districtRepositoryMock,
            festivalRepository: festivalRepositoryMock
        )


        let result = try await subject.getTools(id: "district-id", user: .district("district-id"))


        #expect(result == tool)
        #expect(lastCalledFestivalId == "festival-id")
        #expect(lastCalledDistrictId == "district-id")
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(festivalRepositoryMock.getCallCount == 1)
    }

    @Test func test_getTools_異常_祭典がない() async throws {
        let district = District(id: "district-id", name: "district-name", festivalId: "festival-id", visibility: .all)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            return district
        })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in nil })
        let subject = make(districtRepositoryMock, festivalRepository: festivalRepositoryMock)


        await #expect(throws: Error.notFound("指定された祭典が見つかりません")) {
            let _ = try await subject.getTools(id: "district-id", user: .district("district-id"))
        }


        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(festivalRepositoryMock.getCallCount == 1)
    }
}

extension DistrictUsecaseTests{
    func make(
        _ repository: DistrictRepositoryMock = .init(),
        festivalRepository: FestivalRepositoryMock = .init(),
        authManager: AuthManagerMock = .init()
    ) -> DistrictUsecase {
        let subject = withDependencies {
            $0[DistrictRepositoryKey.self] = repository
            $0[FestivalRepositoryKey.self] = festivalRepository
            $0[AuthManagerFactoryKey.self] = { authManager }
        } operation: {
            DistrictUsecase()
        }
        return subject
    }
}
