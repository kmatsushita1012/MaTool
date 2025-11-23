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

struct DistrictUsecaseTests{
    @Test func test_get_正常() async throws {
        let expected = District(id: "get-id", name: "get-name", festivalId: "get-festival-id", visibility: .all)
        var lastGetId: String? = nil
        let mock = DistrictRepositoryMock(
            getHandler: { id in
                lastGetId = id
                return expected
            }
        )
        let subject = make(repository: mock)
        
        
        let result = try await subject.get("get-id")
        
        
        #expect(result == expected)
        #expect(lastGetId == "get-id")
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
        let subject = make(repository: mock)
        
        
        await #expect(throws: APIError.notFound("指定された地区が見つかりません")) {
            let _ = try await subject.get("get-id")
        }

        
        #expect(lastGetId == "get-id")
        #expect(mock.getCallCount == 1)
    }
    
    @Test func test_get_異常() async throws {
        var lastGetId: String? = nil
        let mock = DistrictRepositoryMock(
            getHandler: { id in
                lastGetId = id
                throw APIError.internalServerError()
            }
        )
        let subject = make(repository: mock)
        
        
        await #expect(throws: APIError.internalServerError()) {
            let _ = try await subject.get("get-id")
        }

        
        #expect(lastGetId == "get-id")
        #expect(mock.getCallCount == 1)
    }

    @Test func test_query_正常() async throws {
        // prepare
        let expected = District(id: "q-id", name: "q-name", festivalId: "f-id", visibility: .all)
        let mock = DistrictRepositoryMock(queryHandler: { festivalId in
            return [expected]
        })
        let subject = make(repository: mock)


        // execute
        let result = try await subject.query(by: "f-id")


        // verify
        #expect(result.count == 1)
        #expect(result.first?.id == "q-id")
        #expect(mock.queryCallCount == 1)
    }

    @Test func test_post_正常() async throws {
        // prepare
        var posted: District? = nil
        let mock = DistrictRepositoryMock(
            getHandler: { id in nil },
            postHandler: { item in
                posted = item
                return item
            }
        )

        struct MockAuthManager: AuthManager {
            func invite(username: String, email: String) async throws -> UserRole {
                return .district(username)
            }
        }

        let subject = withDependencies {
            $0[DistrictRepositoryKey.self] = mock
            $0[FestivalRepositoryKey.self] = FestivalRepositoryMock()
            $0[AuthManagerFactoryKey.self] = { { MockAuthManager() } }
        } operation: {
            DistrictUsecase()
        }


        // execute
        let result = try await subject.post(user: .headquarter("HQ"), headquarterId: "HQ", newDistrictName: "new", email: "a@b.c")


        // verify
        #expect(result.name == "new")
        #expect(posted?.id == "HQ_new")
        #expect(mock.postCallCount == 1)
    }

    @Test func test_put_正常() async throws {
        // prepare
        var putCalled = false
        let mock = DistrictRepositoryMock(
            getHandler: { id in .init(id: "d", name: "n", festivalId: "f", visibility: .all) },
            putHandler: { id, item in
                putCalled = true
                return item
            }
        )
        let subject = make(repository: mock)


        // execute
        let item = District(id: "d", name: "updated", festivalId: "f", visibility: .all)
        let res = try await subject.put(id: "d", item: item, user: .district("d"))


        // verify
        #expect(res.name == "updated")
        #expect(putCalled == true)
        #expect(mock.putCallCount == 1)
    }

    @Test func test_getTools_正常() async throws {
        let district = District(id: "district-id", name: "district-name", festivalId: "festival-id", visibility: .all)
        let festival = Festival(id: "festival-id", name: "festival-name", subname: "festival-subname", description: nil, prefecture: "", city: "", base: Coordinate(latitude: 0, longitude: 0), spans: [], milestones: [], imagePath: nil)
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


        // execute
        let result = try await subject.getTools(id: "id", user: .district("id"))


        // verify
        #expect(tools.districtId == "id")
        #expect(tools.festivalName == "fest-name")
    }
}

extension DistrictUsecaseTests{
    func make(
        _ repository: DistrictRepositoryMock = .init(),
        festivalRepsitory: FestivalRepositoryMock = .init(),
        authManager: AuthManagerMock = .init()
    ) -> DistrictUsecase {
        let subject = withDependencies {
            $0[DistrictRepositoryKey.self] = repository
            $0[FestivalRepositoryKey.self] = festivalRepsitoryMock
            $0[AuthManagerFactoryKey.self] = { authManager() }
        } operation: {
            DistrictUsecase()
        }
        return subject
    }
}
