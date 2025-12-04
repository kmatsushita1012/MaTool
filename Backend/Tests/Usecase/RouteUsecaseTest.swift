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

struct RouteUsecaseTest {

    @Test func test_query_正常() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let expected = RouteItem(from: route)
        
        var lastCalledDistrictId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        var lastCalledQueryDistrictId: String? = nil
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { districtId in
            lastCalledQueryDistrictId = districtId
            return [route]
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.query(by: districtId, user: .district(districtId))
        
        
        #expect(result.count == 1)
        #expect(result.first?.id == expected.id)
        #expect(lastCalledDistrictId == districtId)
        #expect(lastCalledQueryDistrictId == districtId)
        #expect(routeRepositoryMock.queryCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_query_異常_地区が見つからない() async throws {
        let districtId = "district-id"
        var lastCalledDistrictId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return nil
        })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            let _ = try await subject.query(by: districtId, user: .district(districtId))
        }
        
        
        #expect(lastCalledDistrictId == districtId)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_query_異常_AdminOnlyで権限なし_Guest() async throws {
        let districtId = "district-id"
        var lastCalledDistrictId: String? = nil
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.query(by: districtId, user: .guest)
        }
        
        
        #expect(lastCalledDistrictId == districtId)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_query_異常_AdminOnlyで権限なし_異なるDistrict() async throws {
        let districtId = "district-id"
        var lastCalledDistrictId: String? = nil
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.query(by: districtId, user: .district("other-district-id"))
        }
        
        
        #expect(lastCalledDistrictId == districtId)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_query_正常_AdminOnlyでheadquarter権限あり() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        var lastCalledDistrictId: String? = nil
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .admin)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        var lastCalledQueryDistrictId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { districtId in
            lastCalledQueryDistrictId = districtId
            return [route]
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.query(by: districtId, user: .headquarter(festivalId))
        
        
        #expect(result.count == 1)
        #expect(lastCalledDistrictId == districtId)
        #expect(lastCalledQueryDistrictId == districtId)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_query_異常_routeRepositoryエラー() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in
            throw Error.internalServerError("query_failed")
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.internalServerError("query_failed")) {
            let _ = try await subject.query(by: districtId, user: .district(districtId))
        }
        
        
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_get_正常() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        
        var lastCalledRouteId: String? = nil
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { id in
            lastCalledRouteId = id
            return route
        })
        var lastCalledDistrictId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.get(id: routeId, user: .district(districtId))
        
        
        #expect(result.id == routeId)
        #expect(lastCalledRouteId == routeId)
        #expect(lastCalledDistrictId == districtId)
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_異常_ルートが見つからない() async throws {
        let routeId = "route-id"
        var lastCalledRouteId: String? = nil
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { id in
            lastCalledRouteId = id
            return nil
        })
        let districtRepositoryMock = DistrictRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            let _ = try await subject.get(id: routeId, user: .district("district-id"))
        }
        
        
        #expect(lastCalledRouteId == routeId)
        #expect(routeRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_異常_AdminOnlyで権限なし() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
        
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
            return route
        })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
            return district
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.get(id: routeId, user: .guest)
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_Partialで権限なし_Guest() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .route)
        
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
            return route
        })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
            return district
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.get(id: routeId, user: .guest)
        
        
        #expect(result.id == routeId)
        #expect(result.start == SimpleTime(hour: 0, minute: 0))
        #expect(result.goal == SimpleTime(hour: 0, minute: 0))
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_Partialで権限なし_異なるDistrict() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .route)
        
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
            return route
        })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
            return district
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.get(id: routeId, user: .district("other-district-id"))
        
        
        #expect(result.id == routeId)
        #expect(result.start == SimpleTime(hour: 0, minute: 0))
        #expect(result.goal == SimpleTime(hour: 0, minute: 0))
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_Partialで権限あり_District() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .route)
        
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
            return route
        })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
            return district
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.get(id: routeId, user: .district(districtId))
        
        
        #expect(result.id == routeId)
        #expect(result.start == SimpleTime(hour: 10, minute: 0))
        #expect(result.goal == SimpleTime(hour: 11, minute: 0))
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_Partialで権限あり_Headquarter() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let festivalId = "festival-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .route)
        
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
            return route
        })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
            return district
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.get(id: routeId, user: .headquarter(festivalId))
        
        
        #expect(result.id == routeId)
        #expect(result.start == SimpleTime(hour: 10, minute: 0))
        #expect(result.goal == SimpleTime(hour: 11, minute: 0))
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_正常_AdminOnlyでheadquarter権限あり() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let festivalId = "festival-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .admin)
        
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in route })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.get(id: routeId, user: .headquarter(festivalId))
        
        
        #expect(result.id == routeId)
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_異常_AdminOnlyで権限なし_異なるDistrict() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
        
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in route })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.get(id: routeId, user: .district("other-district-id"))
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_異常_routeRepositoryエラー() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
            throw Error.internalServerError("get_failed")
        })
        let districtRepositoryMock = DistrictRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.internalServerError("get_failed")) {
            let _ = try await subject.get(id: routeId, user: .district(districtId))
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_get_異常_districtRepositoryエラー() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in route })
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
            throw Error.internalServerError("district_get_failed")
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.internalServerError("district_get_failed")) {
            let _ = try await subject.get(id: routeId, user: .district(districtId))
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_post_正常() async throws {
        let districtId = "district-id"
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        
        var lastPostedRoute: Route? = nil
        let routeRepositoryMock = RouteRepositoryMock(postHandler: { route in
            lastPostedRoute = route
            return route
        })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        let result = try await subject.post(districtId: districtId, route: route, user: .district(districtId))
        
        
        #expect(result.id == route.id)
        #expect(lastPostedRoute?.id == route.id)
        #expect(routeRepositoryMock.postCallCount == 1)
    }
    
    @Test func test_post_異常_権限なし() async throws {
        let districtId = "district-id"
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.post(districtId: districtId, route: route, user: .guest)
        }
        
        
        #expect(routeRepositoryMock.postCallCount == 0)
    }
    
    @Test func test_post_異常_districtId不一致() async throws {
        let districtId = "district-id"
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.post(districtId: "other-id", route: route, user: .district(districtId))
        }
        
        
        #expect(routeRepositoryMock.postCallCount == 0)
    }
    
    @Test func test_post_異常_routeDistrictId不一致() async throws {
        let districtId = "district-id"
        let route = Route(id: "route-id", districtId: "other-district-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.post(districtId: districtId, route: route, user: .district(districtId))
        }
        
        
        #expect(routeRepositoryMock.postCallCount == 0)
    }
    
    @Test func test_post_異常_routeRepositoryエラー() async throws {
        let districtId = "district-id"
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock(postHandler: { _ in
            throw Error.internalServerError("post_failed")
        })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.internalServerError("post_failed")) {
            let _ = try await subject.post(districtId: districtId, route: route, user: .district(districtId))
        }
        
        
        #expect(routeRepositoryMock.postCallCount == 1)
    }
    
    @Test func test_put_正常() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let oldRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let newRoute = Route(id: routeId, districtId: districtId, title: "updated", start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
        
        var lastCalledRouteId: String? = nil
        var lastPutRoute: Route? = nil
        let routeRepositoryMock = RouteRepositoryMock(
            getHandler: { id in
                lastCalledRouteId = id
                return oldRoute
            },
            putHandler: { route in
                lastPutRoute = route
                return route
            }
        )
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        let result = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        
        
        #expect(result.title == "updated")
        #expect(lastCalledRouteId == routeId)
        #expect(lastPutRoute?.title == "updated")
        #expect(lastPutRoute?.id == routeId)
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.putCallCount == 1)
    }
    
    @Test func test_put_異常_ルートが見つからない() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        var lastCalledRouteId: String? = nil
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { id in
            lastCalledRouteId = id
            return nil
        })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            let _ = try await subject.put(id: routeId, route: route, user: .district(districtId))
        }
        
        
        #expect(lastCalledRouteId == routeId)
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.putCallCount == 0)
    }
    
    @Test func test_put_異常_権限なし_Guest() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in route })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.put(id: routeId, route: route, user: .guest)
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.putCallCount == 0)
    }
    
    @Test func test_put_異常_routeDistrictId不一致() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let oldRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let newRoute = Route(id: routeId, districtId: "other-district-id", start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in oldRoute })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.putCallCount == 0)
    }
    
    @Test func test_put_異常_oldDistrictId不一致() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let oldRoute = Route(id: routeId, districtId: "other-district-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let newRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in oldRoute })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.putCallCount == 0)
    }
    
    @Test func test_put_異常_routeRepositoryエラー() async throws {
        let routeId = "route-id"
        let districtId = "district-id"
        let oldRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let newRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock(
            getHandler: { _ in oldRoute },
            putHandler: { _ in
                throw Error.internalServerError("put_failed")
            }
        )
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.internalServerError("put_failed")) {
            let _ = try await subject.put(id: routeId, route: newRoute, user: .district(districtId))
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.putCallCount == 1)
    }

    @Test func test_delete_正常() async throws {
        let user = UserRole.district("d-id")
        let expected = Route(id: "route-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        var lastCalledGetId: String? = nil
        var lastCalledDeleteId: String? = nil
        let routeRepositoryMock = RouteRepositoryMock(
            getHandler: { id in
                lastCalledGetId = id
                return expected
            },
            deleteHandler: { id in
                lastCalledDeleteId = id
                return
            }
        )
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        try await subject.delete(id: "route-id", user: .district("d-id"))
        
        
        #expect(lastCalledGetId == "route-id")
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(lastCalledDeleteId == "route-id")
        #expect(routeRepositoryMock.deleteCallCount == 1)
    }

    @Test func test_delete_異常_ルートが見つからない() async throws {
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in nil })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            let _ = try await subject.delete(id: "route-id", user: .district("d-id"))
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.deleteCallCount == 0)
    }

    @Test func test_delete_異常_ゲスト() async throws {
        let expected = Route(id: "route-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in expected })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.delete(id: "route-id", user: .guest)
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.deleteCallCount == 0)
    }

    @Test func test_delete_異常_別のDistrict() async throws {
        let expected = Route(id: "route-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in expected })
        let subject = make(routeRepository: routeRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.delete(id: "route-id", user: .district("other-id"))
        }
        
        
        #expect(routeRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.deleteCallCount == 0)
    }


    @Test func test_getAllRouteIds_正常() async throws {
        let festivalId = "festival-id"
        let district1 = District(id: "district-1", name: "district-1", festivalId: festivalId, visibility: .all)
        let district2 = District(id: "district-2", name: "district-2", festivalId: festivalId, visibility: .all)
        let route1 = Route(id: "route-1", districtId: "district-1", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let route2 = Route(id: "route-2", districtId: "district-2", start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
        
        var lastCalledFestivalId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(queryHandler: { festivalId in
            lastCalledFestivalId = festivalId
            return [district1, district2]
        })
        var calledDistrictIds: [String] = []
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { districtId in
            calledDistrictIds.append(districtId)
            if districtId == "district-1" {
                return [route1]
            } else {
                return [route2]
            }
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.getAllRouteIds(user: .headquarter(festivalId))
        
        
        #expect(result.count == 2)
        #expect(result.contains("route-1"))
        #expect(result.contains("route-2"))
        #expect(lastCalledFestivalId == festivalId)
        #expect(calledDistrictIds.contains("district-1"))
        #expect(calledDistrictIds.contains("district-2"))
        #expect(districtRepositoryMock.queryCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 2)
    }
    
    @Test func test_getAllRouteIds_異常_権限なし() async throws {
        let routeRepositoryMock = RouteRepositoryMock()
        let districtRepositoryMock = DistrictRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.getAllRouteIds(user: .guest)
        }
        
        
        #expect(districtRepositoryMock.queryCallCount == 0)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_getAllRouteIds_異常_地区が見つからない() async throws {
        let festivalId = "festival-id"
        var lastCalledFestivalId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(queryHandler: { festivalId in
            lastCalledFestivalId = festivalId
            return []
        })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.getAllRouteIds(user: .headquarter(festivalId))
        }
        
        
        #expect(lastCalledFestivalId == festivalId)
        #expect(districtRepositoryMock.queryCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_getAllRouteIds_異常_districtRepositoryエラー() async throws {
        let festivalId = "festival-id"
        let districtRepositoryMock = DistrictRepositoryMock(queryHandler: { _ in
            throw Error.internalServerError("query_failed")
        })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.internalServerError("query_failed")) {
            let _ = try await subject.getAllRouteIds(user: .headquarter(festivalId))
        }
        
        
        #expect(districtRepositoryMock.queryCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_getAllRouteIds_異常_routeRepositoryエラー() async throws {
        let festivalId = "festival-id"
        let district = District(id: "district-1", name: "district-1", festivalId: festivalId, visibility: .all)
        let districtRepositoryMock = DistrictRepositoryMock(queryHandler: { _ in [district] })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in
            throw Error.internalServerError("route_query_failed")
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.internalServerError("route_query_failed")) {
            let _ = try await subject.getAllRouteIds(user: .headquarter(festivalId))
        }
        
        
        #expect(districtRepositoryMock.queryCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let location = FloatLocation(districtId: districtId, coordinate: Coordinate(latitude: 1.0, longitude: 2.0), timestamp: Date())
        
        var lastCalledDistrictId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        var lastCalledQueryDistrictId: String? = nil
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { districtId in
            lastCalledQueryDistrictId = districtId
            return [route]
        })
        var lastCalledLocationId: String? = nil
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { id in
            lastCalledLocationId = id
            return location
        })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock
        )
        
        
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let result = try await subject.getCurrent(districtId: districtId, user: .district(districtId), now: fixedDate)
        
        
        #expect(result.districtId == districtId)
        #expect(result.districtName == district.name)
        #expect(result.routes?.count == 1)
        #expect(result.current?.id == route.id)
        #expect(result.location?.districtId == districtId)
        #expect(lastCalledDistrictId == districtId)
        #expect(lastCalledQueryDistrictId == districtId)
        #expect(lastCalledLocationId == districtId)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
        #expect(locationRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_getCurrent_異常_地区が見つからない() async throws {
        let districtId = "district-id"
        var lastCalledDistrictId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return nil
        })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            let fixedDate = makeDate(year: 2023, month: 11, day: 15)
            let _ = try await subject.getCurrent(districtId: districtId, user: .district(districtId), now: fixedDate)
        }
        
        
        #expect(lastCalledDistrictId == districtId)
        #expect(districtRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_getCurrent_AdminOnlyで権限なし_Guest() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.routes == nil)
        #expect(result.current == nil)
        #expect(result.location == nil)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_getCurrent_AdminOnlyで権限なし_異なるDistrict() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let result = try await subject.getCurrent(districtId: districtId, user: .district("other-district-id"), now: fixedDate)
        
        
        #expect(result.routes == nil)
        #expect(result.current == nil)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_getCurrent_AdminOnlyで権限あり_District() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let location = FloatLocation(districtId: districtId, coordinate: Coordinate(latitude: 1.0, longitude: 2.0), timestamp: Date())
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _ in location })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock
        )
        
        
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let result = try await subject.getCurrent(districtId: districtId, user: .district(districtId), now: fixedDate)
        
        
        #expect(result.routes?.count == 1)
        #expect(result.current?.id == route.id)
        #expect(result.location?.districtId == districtId)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
        #expect(locationRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_getCurrent_AdminOnlyで権限あり_Headquarter() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .admin)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let location = FloatLocation(districtId: districtId, coordinate: Coordinate(latitude: 1.0, longitude: 2.0), timestamp: Date())
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _ in location })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock
        )
        
        
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let result = try await subject.getCurrent(districtId: districtId, user: .headquarter(festivalId), now: fixedDate)
        
        
        #expect(result.routes?.count == 1)
        #expect(result.current?.id == route.id)
        #expect(result.location?.districtId == districtId)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
        #expect(locationRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_AdminAccessでLocation取得() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let location = FloatLocation(districtId: districtId, coordinate: Coordinate(latitude: 1.0, longitude: 2.0), timestamp: Date())
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _ in location })
        let festivalRepositoryMock = FestivalRepositoryMock()
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock,
            festivalRepository: festivalRepositoryMock
        )
        
        
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let result = try await subject.getCurrent(districtId: districtId, user: .headquarter(festivalId), now: fixedDate)
        
        
        #expect(result.location?.districtId == districtId)
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(festivalRepositoryMock.getCallCount == 0)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_PublicAccessでLocation取得() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let location = FloatLocation(districtId: districtId, coordinate: Coordinate(latitude: 1.0, longitude: 2.0), timestamp: Date())
        let fixedDate = makeDate(year: 2023, month: 11, day: 15, hour: 0, minute: 1) // 2023-11-15 00:01:00 UTC
        let festival = Festival(id: festivalId, name: "festival", subname: "sub", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0), periods: [.init(id: "p-id", title: "p-title", date: .init(year: 2023, month: 11, day: 15), start: .init(hour: 0, minute: 0), end: .init(hour: 0, minute: 2))])
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _ in location })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in festival })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock,
            festivalRepository: festivalRepositoryMock
        )
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.location?.districtId == districtId)
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(festivalRepositoryMock.getCallCount == 1)
    }
    
    @Test func test_getCurrent_異常_PublicAccessで期間外() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let fixedDate = makeDate(year: 2023, month: 11, day: 15) // 2023-11-15 00:00:00 UTC
        let festival = Festival(id: festivalId, name: "festival", subname: "sub", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0), periods: [.init(id: "p-id", title: "p-title", date: .init(year: 2023, month: 11, day: 15), start: .init(hour: 0, minute: 1), end: .init(hour: 0, minute: 2))])
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock()
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in festival })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock,
            festivalRepository: festivalRepositoryMock
        )
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.location == nil)
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(locationRepositoryMock.getCallCount == 0)
    }
    
    @Test func test_getCurrent_正常_Partialで時間削除() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .route)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.current?.id == route.id)
        #expect(result.current?.start == SimpleTime(hour: 0, minute: 0))
        #expect(result.current?.goal == SimpleTime(hour: 0, minute: 0))
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_routeListが空() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [] })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .district(districtId), now: fixedDate)
        
        
        #expect(result.routes?.isEmpty == true)
        #expect(result.current == nil)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_進行中のルートを選択() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        // 2023-11-15 00:45:00 UTC (進行中のルートを選択)
        let fixedDate = makeDate(year: 2023, month: 11, day: 15, hour: 0, minute: 45)
        let routeDate = SimpleDate(year: 2023, month: 11, day: 15)
        let route1 = Route(id: "route-1", districtId: districtId, date: routeDate, start: SimpleTime(hour: 8, minute: 0), goal: SimpleTime(hour: 9, minute: 0))
        let route2 = Route(id: "route-2", districtId: districtId, date: routeDate, start: SimpleTime(hour: 0, minute: 30), goal: SimpleTime(hour: 1, minute: 0)) // 進行中
        let route3 = Route(id: "route-3", districtId: districtId, date: routeDate, start: SimpleTime(hour: 2, minute: 0), goal: SimpleTime(hour: 3, minute: 0))
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route1, route2, route3] })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .district(districtId), now: fixedDate)
        
        
        #expect(result.current?.id == "route-2")
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_未来のルートを選択() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        // 2023-11-15 00:00:00 UTC (未来のルートを選択)
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let routeDate = SimpleDate(year: 2023, month: 11, day: 15)
        let route1 = Route(id: "route-1", districtId: districtId, date: routeDate, start: SimpleTime(hour: 1, minute: 0), goal: SimpleTime(hour: 2, minute: 0)) // 未来
        let route2 = Route(id: "route-2", districtId: districtId, date: routeDate, start: SimpleTime(hour: 3, minute: 0), goal: SimpleTime(hour: 4, minute: 0))
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route1, route2] })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .district(districtId), now: fixedDate)
        
        
        #expect(result.current?.id == "route-1")
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_過去のルートを選択() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        // 2023-11-15 00:00:00 UTC (過去のルートを選択 - 前日のルートが選択される)
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        let routeDate = SimpleDate(year: 2023, month: 11, day: 14)
        let route1 = Route(id: "route-1", districtId: districtId, date: routeDate, start: SimpleTime(hour: 20, minute: 0), goal: SimpleTime(hour: 21, minute: 0)) // 過去
        let route2 = Route(id: "route-2", districtId: districtId, date: routeDate, start: SimpleTime(hour: 22, minute: 0), goal: SimpleTime(hour: 23, minute: 0))
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route1, route2] })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .district(districtId), now: fixedDate)
        
        
        #expect(result.current?.id == "route-1")
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_AdminAccessでLocationが見つからない() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _ in nil })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock
        )
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .headquarter(festivalId), now: fixedDate)
        
        
        #expect(result.location == nil)
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_PublicAccessでFestivalが見つからない() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let fixedDate = makeDate(year: 2023, month: 11, day: 15)
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock()
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in nil })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock,
            festivalRepository: festivalRepositoryMock
        )
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.location == nil)
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(locationRepositoryMock.getCallCount == 0)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_PublicAccessでLocationが見つからない() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let fixedDate = makeDate(year: 2023, month: 11, day: 15, hour: 0, minute: 2)
        let festival = Festival(id: festivalId, name: "festival", subname: "sub", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0), periods: [.init(id: "p-id", title: "p-title", date: .init(year: 2023, month: 11, day: 15), start: .init(hour: 0, minute: 0), end: .init(hour: 0, minute: 2))])
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _ in nil })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in festival })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock,
            festivalRepository: festivalRepositoryMock
        )
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.location == nil)
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_正常_routeListがnilの場合() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock()
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.routes == nil)
        #expect(result.current == nil)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 0)
    }
    
    @Test func test_getCurrent_異常_routeRepositoryエラー() async throws {
        let districtId = "district-id"
        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in
            throw Error.internalServerError("query_failed")
        })
        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .district(districtId), now: fixedDate)
        
        
        #expect(result.routes == nil)
        #expect(result.current == nil)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_異常_AdminAccessでlocationRepositoryエラー() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _ in
            throw Error.internalServerError("location_get_failed")
        })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock
        )
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .headquarter(festivalId), now: fixedDate)
        
        
        #expect(result.location == nil)
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_異常_PublicAccessでlocationRepositoryエラー() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let fixedDate = makeDate(year: 2023, month: 11, day: 15, hour: 0, minute: 0)
        let festival = Festival(id: festivalId, name: "festival", subname: "sub", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0), periods: [.init(id: "p-id", title: "p-title", date: .init(year: 2023, month: 11, day: 15), start: .init(hour: 0, minute: 0), end: .init(hour: 0, minute: 2))])
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _ in
            throw Error.internalServerError("location_get_failed")
        })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in festival })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock,
            festivalRepository: festivalRepositoryMock
        )
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.location == nil)
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_getCurrent_異常_PublicAccessでfestivalRepositoryエラー() async throws {
        let districtId = "district-id"
        let festivalId = "festival-id"
        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .all)
        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in [route] })
        let locationRepositoryMock = LocationRepositoryMock()
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in
            throw Error.internalServerError("festival_get_failed")
        })
        let subject = make(
            routeRepository: routeRepositoryMock,
            districtRepository: districtRepositoryMock,
            locationRepository: locationRepositoryMock,
            festivalRepository: festivalRepositoryMock
        )
        
        
        let result = try await subject.getCurrent(districtId: districtId, user: .guest, now: fixedDate)
        
        
        #expect(result.location == nil)
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(locationRepositoryMock.getCallCount == 0)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(routeRepositoryMock.queryCallCount == 1)
    }
}

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
