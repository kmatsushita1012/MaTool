//
//  RouteUsecaseTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/30.
//

import Foundation
import Testing
@testable import Backend
import Dependencies
import Shared

@Suite
struct RouteUsecaseTest {

    // MARK: - query(by: user) -> [RoutesResponse]
    @Test func test_query_list_success_allVisibility() async throws {
        // Arrange
        let districtId = "d-id"
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .all)
        let period = Period(id: "p-id", festivalId: "f-id", date: .init(year: 2025, month: 12, day: 29), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))
        let expected = RoutesResponse(districtId: districtId, districtName: district.name, items: [
            .init(routeId: "r-id", isVisible: true, period: period)
        ])

        var capturedDistrictId: String? = nil
        let districtRepository = DistrictRepositoryMock(getHandler: { id in
            capturedDistrictId = id
            return district
        })
        var capturedQueryDistrictId: String? = nil
        let routeRepository = RouteRepositoryMock(queryHandler: { id in
            capturedQueryDistrictId = id
            let route = Route(id: "r-id", districtId: id, periodId: period.id)
            return [RouteRecord(item: route, year: period.date.year)]
        })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        // Act
        let result = try await subject.query(by: districtId, user: .district(districtId))

        // Assert
        #expect(result == expected)
        #expect(capturedDistrictId == districtId)
        #expect(capturedQueryDistrictId == districtId)
        #expect(districtRepository.getCallCount == 1)
        #expect(routeRepository.queryCallCount == 1)
    }

    @Test func test_query_list_unauthorized_guest_whenAdminOnly() async throws {
        let districtId = "d-id"
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .admin)
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepository = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.query(by: districtId, user: .guest)
        }
        #expect(districtRepository.getCallCount == 1)
        #expect(routeRepository.queryCallCount == 0)
    }

    @Test func test_query_list_unauthorized_otherDistrict_whenAdminOnly() async throws {
        let districtId = "d-id"
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .admin)
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepository = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.query(by: districtId, user: .district("other"))
        }
        #expect(districtRepository.getCallCount == 1)
        #expect(routeRepository.queryCallCount == 0)
    }

    @Test func test_query_list_headquarter_allowed_whenAdminOnly() async throws {
        let districtId = "d-id"
        let festivalId = "f-id"
        let district = District(id: districtId, name: "d-name", festivalId: festivalId, visibility: .admin)
        let period = Period(id: "p-id", festivalId: festivalId, date: .init(year: 2025, month: 12, day: 29), start: .init(hour: 10, minute: 0), end: .init(hour: 11, minute: 0))
        let expected = RoutesResponse(districtId: districtId, districtName: district.name, items: [
            .init(routeId: "r-id", isVisible: true, period: period)
        ])
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepository = RouteRepositoryMock(queryHandler: { id in
            let route = Route(id: "r-id", districtId: id, periodId: period.id)
            return [RouteRecord(item: route, year: period.date.year)]
        })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        let result = try await subject.query(by: districtId, user: .headquarter(festivalId))
        #expect(result == expected)
        #expect(districtRepository.getCallCount == 1)
        #expect(routeRepository.queryCallCount == 1)
    }

    @Test func test_query_list_notFound_district() async throws {
        let districtId = "d-id"
        var captured: String? = nil
        let districtRepository = DistrictRepositoryMock(getHandler: { id in captured = id; return nil })
        let routeRepository = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            _ = try await subject.query(by: districtId, user: .district(districtId))
        }
        #expect(captured == districtId)
        #expect(districtRepository.getCallCount == 1)
        #expect(routeRepository.queryCallCount == 0)
    }

    @Test func test_query_list_repositoryError_propagates() async throws {
        let districtId = "d-id"
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .all)
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepository = RouteRepositoryMock(queryHandler: { _ in
            throw Error.internalServerError("query_failed")
        })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        await #expect(throws: Error.internalServerError("query_failed")) {
            _ = try await subject.query(by: districtId, user: .district(districtId))
        }
        #expect(districtRepository.getCallCount == 1)
        #expect(routeRepository.queryCallCount == 1)
    }

    // MARK: - get(id:user) -> RouteResponse
    @Test func test_get_success_allVisibility() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let route = Route(id: routeId, districtId: districtId, periodId: "p-id")
        let record = RouteRecord(item: route, year: 2025)
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .all)
        let expected = RouteResponse(districtId: "d-id", districtName: "d-name", period: .init(id: "p-id", festivalId: "f-id", date: .init(year: 2025, month: 12, day: 29), start: .init(hour: 14, minute: 58), end: .init(hour: 14, minute: 59)), route: route)

        var capturedGetId: String? = nil
        let routeRepository = RouteRepositoryMock(getHandler: { id in capturedGetId = id; return record })
        var capturedDistrictId: String? = nil
        let districtRepository = DistrictRepositoryMock(getHandler: { id in capturedDistrictId = id; return district })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        let result = try await subject.get(id: routeId, user: .district(districtId))

        #expect(result == expected)
        #expect(capturedGetId == routeId)
        #expect(capturedDistrictId == districtId)
        #expect(routeRepository.getCallCount == 1)
        #expect(districtRepository.getCallCount == 1)
    }

    @Test func test_get_notFound_route() async throws {
        let routeId = "r-id"
        let routeRepository = RouteRepositoryMock(getHandler: { _ in nil })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            _ = try await subject.get(id: routeId, user: .district("d-id"))
        }
        #expect(routeRepository.getCallCount == 1)
    }

    @Test func test_get_unauthorized_guest_whenAdminOnly() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let route = Route(id: routeId, districtId: districtId, periodId: "p-idß")
        let period = Period(id: "p-id", fesdate: <#T##SimpleDate#>, start: <#T##SimpleTime#>, end: <#T##SimpleTime#>)
        let record = RouteRecord(item: route, year: 2025)
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .admin)
        let expected = RouteResponse(districtId: "d-id", districtName: "d-name", period: <#T##Period#>, route: <#T##Route#>)
        let routeRepository = RouteRepositoryMock(getHandler: { _ in record })
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.get(id: routeId, user: .guest)
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(districtRepository.getCallCount == 1)
    }

    @Test func test_get_partial_visibility_guest_otherDistrict_allowed() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let route = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .route)
        let expected = RouteResponse(id: routeId, districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock(getHandler: { _ in route })
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        let result = try await subject.get(id: routeId, user: .guest)
        #expect(result == expected)
        #expect(routeRepository.getCallCount == 1)
        #expect(districtRepository.getCallCount == 1)
    }

    @Test func test_get_partial_visibility_district_mismatch_allowed() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let route = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .route)
        let expected = RouteResponse(id: routeId, districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock(getHandler: { _ in route })
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        let result = try await subject.get(id: routeId, user: .district("other"))
        #expect(result == expected)
        #expect(routeRepository.getCallCount == 1)
        #expect(districtRepository.getCallCount == 1)
    }

    @Test func test_get_headquarter_allowed_whenAdminOnly() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let festivalId = "f-id"
        let route = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let district = District(id: districtId, name: "d-name", festivalId: festivalId, visibility: .admin)
        let expected = RouteResponse(id: routeId, districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock(getHandler: { _ in route })
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        let result = try await subject.get(id: routeId, user: .headquarter(festivalId))
        #expect(result == expected)
        #expect(routeRepository.getCallCount == 1)
        #expect(districtRepository.getCallCount == 1)
    }

    @Test func test_get_unauthorized_otherDistrict_whenAdminOnly() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let route = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let district = District(id: districtId, name: "d-name", festivalId: "f-id", visibility: .admin)
        let expected = RouteResponse(id: routeId, districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock(getHandler: { _ in route })
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.get(id: routeId, user: .district("other"))
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(districtRepository.getCallCount == 1)
    }

    @Test func test_get_repositoryError_propagates() async throws {
        let routeId = "r-id"
        let routeRepository = RouteRepositoryMock(getHandler: { _ in
            throw Error.internalServerError("get_failed")
        })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.internalServerError("get_failed")) {
            _ = try await subject.get(id: routeId, user: .district("d-id"))
        }
        #expect(routeRepository.getCallCount == 1)
    }

    @Test func test_get_districtRepositoryError_propagates() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let route = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let routeRepository = RouteRepositoryMock(getHandler: { _ in route })
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in
            throw Error.internalServerError("district_get_failed")
        })
        let subject = make(routeRepository: routeRepository, districtRepository: districtRepository)

        await #expect(throws: Error.internalServerError("district_get_failed")) {
            _ = try await subject.get(id: routeId, user: .district(districtId))
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(districtRepository.getCallCount == 1)
    }

    // MARK: - post
    @Test func test_post_success() async throws {
        let districtId = "d-id"
        let route = Route(id: "r-id", districtId: districtId, periodId: "p-id")
        var capturedPost: RouteRecord? = nil
        let routeRepository = RouteRepositoryMock(postHandler: { r in capturedPost = r; return r })
        let subject = make(routeRepository: routeRepository)

        let result = try await subject.post(districtId: districtId, route: route, user: .district(districtId))

        #expect(result == route)
        #expect(capturedPost?.id == route.id)
        #expect(routeRepository.postCallCount == 1)
    }

    @Test func test_post_unauthorized_guest() async throws {
        let districtId = "d-id"
        let route = Route(id: "r-id", districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.post(districtId: districtId, route: route, user: .guest)
        }
        #expect(routeRepository.postCallCount == 0)
    }

    @Test func test_post_unauthorized_districtIdMismatch_param() async throws {
        let districtId = "d-id"
        let route = Route(id: "r-id", districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.post(districtId: "other", route: route, user: .district(districtId))
        }
        #expect(routeRepository.postCallCount == 0)
    }

    @Test func test_post_unauthorized_routeDistrictMismatch() async throws {
        let districtId = "d-id"
        let route = Route(id: "r-id", districtId: "other", periodId: "p-id")
        let routeRepository = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.post(districtId: districtId, route: route, user: .district(districtId))
        }
        #expect(routeRepository.postCallCount == 0)
    }

    @Test func test_post_repositoryError_propagates() async throws {
        let districtId = "d-id"
        let route = Route(id: "r-id", districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock(postHandler: { _ in
            throw Error.internalServerError("post_failed")
        })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.internalServerError("post_failed")) {
            _ = try await subject.post(districtId: districtId, route: route, user: .district(districtId))
        }
        #expect(routeRepository.postCallCount == 1)
    }

    // MARK: - put
    @Test func test_put_success() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let oldRoute = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let newRoute = Route(id: routeId, districtId: districtId, periodId: "p-id")
        var capturedGetId: String? = nil
        var capturedPut: RouteRecord? = nil
        let routeRepository = RouteRepositoryMock(
            getHandler: { id in capturedGetId = id; return oldRoute },
            putHandler: { r in capturedPut = r; return r }
        )
        let subject = make(routeRepository: routeRepository)

        let result = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        let expected = newRoute

        #expect(result == expected)
        #expect(capturedGetId == routeId)
        #expect(capturedPut?.id == routeId)
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.putCallCount == 1)
    }

    @Test func test_put_notFound_route() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let newRoute = Route(id: routeId, districtId: districtId, periodId: "p-id")
        var capturedGetId: String? = nil
        let routeRepository = RouteRepositoryMock(getHandler: { id in capturedGetId = id; return nil })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            _ = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        }
        #expect(capturedGetId == routeId)
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.putCallCount == 0)
    }

    @Test func test_put_unauthorized_guest() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let route = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let newRoute = Route(id: routeId, districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock(getHandler: { _ in route })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.put(id: routeId, route: newRoute, user: .guest)
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.putCallCount == 0)
    }

    @Test func test_put_unauthorized_paramDistrictMismatch() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let oldRoute = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let newRoute = Route(id: routeId, districtId: "other", periodId: "p-id")
        let routeRepository = RouteRepositoryMock(getHandler: { _ in oldRoute })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.putCallCount == 0)
    }

    @Test func test_put_unauthorized_oldRouteDistrictMismatch() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let oldRoute = RouteRecord(item: Route(id: routeId, districtId: "other", periodId: "p-id"), year: 2025)
        let newRoute = Route(id: routeId, districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock(getHandler: { _ in oldRoute })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.putCallCount == 0)
    }

    @Test func test_put_repositoryError_propagates() async throws {
        let routeId = "r-id"
        let districtId = "d-id"
        let oldRoute = RouteRecord(item: Route(id: routeId, districtId: districtId, periodId: "p-id"), year: 2025)
        let newRoute = Route(id: routeId, districtId: districtId, periodId: "p-id")
        let routeRepository = RouteRepositoryMock(
            getHandler: { _ in oldRoute },
            putHandler: { _ in
                throw Error.internalServerError("put_failed")
            }
        )
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.internalServerError("put_failed")) {
            _ = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.putCallCount == 1)
    }

    // MARK: - delete
    @Test func test_delete_success() async throws {
        let user = UserRole.district("d-id")
        let expected = RouteRecord(item: Route(id: "route-id", districtId: "d-id", periodId: "p-id"), year: 2025)
        var capturedGet: String? = nil
        var capturedDelete: String? = nil
        let routeRepository = RouteRepositoryMock(
            getHandler: { id in capturedGet = id; return expected },
            deleteHandler: { id in capturedDelete = id; return }
        )
        let subject = make(routeRepository: routeRepository)

        try await subject.delete(id: "route-id", user: user)

        #expect(capturedGet == "route-id")
        #expect(routeRepository.getCallCount == 1)
        #expect(capturedDelete == "route-id")
        #expect(routeRepository.deleteCallCount == 1)
    }

    @Test func test_delete_notFound_route() async throws {
        let routeRepository = RouteRepositoryMock(getHandler: { _ in nil })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            _ = try await subject.delete(id: "route-id", user: .district("d-id"))
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.deleteCallCount == 0)
    }

    @Test func test_delete_unauthorized_guest() async throws {
        let expected = RouteRecord(item: Route(id: "route-id", districtId: "d-id", periodId: "p-id"), year: 2025)
        let routeRepository = RouteRepositoryMock(getHandler: { _ in expected })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.delete(id: "route-id", user: .guest)
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.deleteCallCount == 0)
    }

    @Test func test_delete_unauthorized_otherDistrict() async throws {
        let expected = RouteRecord(item: Route(id: "route-id", districtId: "d-id", periodId: "p-id"), year: 2025)
        let routeRepository = RouteRepositoryMock(getHandler: { _ in expected })
        let subject = make(routeRepository: routeRepository)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            _ = try await subject.delete(id: "route-id", user: .district("other-id"))
        }
        #expect(routeRepository.getCallCount == 1)
        #expect(routeRepository.deleteCallCount == 0)
    }
}

// MARK: - Helpers
extension RouteUsecaseTest {
    func make(
        routeRepository: RouteRepositoryMock = .init(),
        districtRepository: DistrictRepositoryMock = .init(),
        locationRepository: LocationRepositoryMock = .init(),
        festivalRepository: FestivalRepositoryMock = .init()
    ) -> RouteUsecase {
        let subject = withDependencies {
            $0[RouteRepositoryKey.self] = routeRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[LocationRepositoryKey.self] = locationRepository
            $0[FestivalRepositoryKey.self] = festivalRepository
        } operation: {
            RouteUsecase()
        }
        return subject
    }
}

