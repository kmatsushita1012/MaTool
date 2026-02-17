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

//@Suite(.disabled())
//struct RouteUsecaseTest {
//
//    @Test func test_query_all_正常() async throws {
//        let districtId = "district-id"
//        let district = District.mock()
//        let expected = Route.mock()
//        
//        var lastCalledDistrictId: String? = nil
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
//            lastCalledDistrictId = id
//            return district
//        })
//        var lastCalledQueryDistrictId: String? = nil
//        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { districtId in
//            lastCalledQueryDistrictId = districtId
//            return [expected]
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        let result = try await subject.query(by: districtId, type: .all, user: UserRole.district(districtId))
//        
//        
//        #expect(result.count == 1)
//        #expect(result.first?.id == expected.id)
//        #expect(lastCalledDistrictId == districtId)
//        #expect(lastCalledQueryDistrictId == districtId)
//        #expect(routeRepositoryMock.queryCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_query_異常_地区が見つからない() async throws {
//        let districtId = "district-id"
//        var lastCalledDistrictId: String? = nil
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
//            lastCalledDistrictId = id
//            return nil
//        })
//        let routeRepositoryMock = RouteRepositoryMock()
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
//            let _ = try await subject.query(by: districtId, type: .all, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(lastCalledDistrictId == districtId)
//        #expect(districtRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.queryCallCount == 0)
//    }
//    
//    @Test func test_query_異常_AdminOnlyで権限なし_Guest() async throws {
//        let districtId = "district-id"
//        var lastCalledDistrictId: String? = nil
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
//            lastCalledDistrictId = id
//            return district
//        })
//        let routeRepositoryMock = RouteRepositoryMock()
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.query(by: districtId, type: .all, user: UserRole.guest)
//        }
//        
//        
//        #expect(lastCalledDistrictId == districtId)
//        #expect(districtRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.queryCallCount == 0)
//    }
//    
//    @Test func test_query_all_異常_AdminOnlyで権限なし_異なるDistrict() async throws {
//        let districtId = "district-id"
//        var lastCalledDistrictId: String? = nil
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
//            lastCalledDistrictId = id
//            return district
//        })
//        let routeRepositoryMock = RouteRepositoryMock()
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.query(by: districtId, type: .all, user: UserRole.district("other-district-id"))
//        }
//        
//        
//        #expect(lastCalledDistrictId == districtId)
//        #expect(districtRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.queryCallCount == 0)
//    }
//    
//    @Test func test_query_正常_AdminOnlyでheadquarter権限あり() async throws {
//        let districtId = "district-id"
//        let festivalId = "festival-id"
//        var lastCalledDistrictId: String? = nil
//        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .admin)
//        let route = Route.mock()
//        var lastCalledQueryDistrictId: String? = nil
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
//            lastCalledDistrictId = id
//            return district
//        })
//        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { districtId in
//            lastCalledQueryDistrictId = districtId
//            return [route]
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        let result = try await subject.query(by: districtId, type: .all, user: UserRole.headquarter(festivalId))
//        
//        
//        #expect(result.count == 1)
//        #expect(lastCalledDistrictId == districtId)
//        #expect(lastCalledQueryDistrictId == districtId)
//        #expect(districtRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.queryCallCount == 1)
//    }
//    
//    @Test func test_query_異常_routeRepositoryエラー() async throws {
//        let districtId = "district-id"
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
//        let routeRepositoryMock = RouteRepositoryMock(queryHandler: { _ in
//            throw Error.internalServerError("query_failed")
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.internalServerError("query_failed")) {
//            let _ = try await subject.query(by: districtId, type: .all, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(districtRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.queryCallCount == 1)
//    }
//    
//    @Test func test_get_正常() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route.mock()
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .all)
//        
//        var lastCalledRouteId: String? = nil
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { id in
//            lastCalledRouteId = id
//            return route
//        })
//        var lastCalledDistrictId: String? = nil
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
//            lastCalledDistrictId = id
//            return district
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        let result = try await subject.get(id: routeId, user: UserRole.district(districtId))
//        
//        
//        #expect(result.id == routeId)
//        #expect(lastCalledRouteId == routeId)
//        #expect(lastCalledDistrictId == districtId)
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_異常_ルートが見つからない() async throws {
//        let routeId = "route-id"
//        var lastCalledRouteId: String? = nil
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { id in
//            lastCalledRouteId = id
//            return nil
//        })
//        let districtRepositoryMock = DistrictRepositoryMock()
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
//            let _ = try await subject.get(id: routeId, user: UserRole.district("district-id"))
//        }
//        
//        
//        #expect(lastCalledRouteId == routeId)
//        #expect(routeRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_異常_AdminOnlyで権限なし() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
//        
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
//            return route
//        })
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
//            return district
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.get(id: routeId, user: UserRole.guest)
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_Partialで権限なし_Guest() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .route)
//        
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
//            return route
//        })
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
//            return district
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        let result = try await subject.get(id: routeId, user: UserRole.guest)
//        
//        
//        #expect(result.id == routeId)
//        #expect(result.start == SimpleTime(hour: 0, minute: 0))
//        #expect(result.goal == SimpleTime(hour: 0, minute: 0))
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_Partialで権限なし_異なるDistrict() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .route)
//        
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
//            return route
//        })
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
//            return district
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        let result = try await subject.get(id: routeId, user: UserRole.district("other-district-id"))
//        
//        
//        #expect(result.id == routeId)
//        #expect(result.start == SimpleTime(hour: 0, minute: 0))
//        #expect(result.goal == SimpleTime(hour: 0, minute: 0))
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_Partialで権限あり_District() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .route)
//        
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
//            return route
//        })
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
//            return district
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        let result = try await subject.get(id: routeId, user: UserRole.district(districtId))
//        
//        
//        #expect(result.id == routeId)
//        #expect(result.start == SimpleTime(hour: 10, minute: 0))
//        #expect(result.goal == SimpleTime(hour: 11, minute: 0))
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_Partialで権限あり_Headquarter() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let festivalId = "festival-id"
//        let route = Route.mock()
//        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .route)
//        
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
//            return route
//        })
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
//            return district
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        let result = try await subject.get(id: routeId, user: UserRole.headquarter(festivalId))
//        
//        
//        #expect(result.id == routeId)
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_正常_AdminOnlyでheadquarter権限あり() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let festivalId = "festival-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let district = District(id: districtId, name: "district-name", festivalId: festivalId, visibility: .admin)
//        
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in route })
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        let result = try await subject.get(id: routeId, user: UserRole.headquarter(festivalId))
//        
//        
//        #expect(result.id == routeId)
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_異常_AdminOnlyで権限なし_異なるDistrict() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let district = District(id: districtId, name: "district-name", festivalId: "festival-id", visibility: .admin)
//        
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in route })
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.get(id: routeId, user: UserRole.district("other-district-id"))
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_異常_routeRepositoryエラー() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in
//            throw Error.internalServerError("get_failed")
//        })
//        let districtRepositoryMock = DistrictRepositoryMock()
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.internalServerError("get_failed")) {
//            let _ = try await subject.get(id: routeId, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_get_異常_districtRepositoryエラー() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in route })
//        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in
//            throw Error.internalServerError("district_get_failed")
//        })
//        let subject = make(routeRepository: routeRepositoryMock, districtRepository: districtRepositoryMock)
//        
//        
//        await #expect(throws: Error.internalServerError("district_get_failed")) {
//            let _ = try await subject.get(id: routeId, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(districtRepositoryMock.getCallCount == 1)
//    }
//    
//    @Test func test_post_正常() async throws {
//        let districtId = "district-id"
//        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        
//        var lastPostedRoute: Route? = nil
//        let routeRepositoryMock = RouteRepositoryMock(postHandler: { route in
//            lastPostedRoute = route
//            return route
//        })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        let result = try await subject.post(districtId: districtId, pack: route, user: UserRole.district(districtId))
//        
//        
//        #expect(result.id == route.id)
//        #expect(lastPostedRoute?.id == route.id)
//        #expect(routeRepositoryMock.postCallCount == 1)
//    }
//    
//    @Test func test_post_異常_権限なし() async throws {
//        let districtId = "district-id"
//        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock()
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.post(districtId: districtId, pack: route, user: UserRole.guest)
//        }
//        
//        
//        #expect(routeRepositoryMock.postCallCount == 0)
//    }
//    
//    @Test func test_post_異常_districtId不一致() async throws {
//        let districtId = "district-id"
//        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock()
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.post(districtId: "other-id", pack: route, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(routeRepositoryMock.postCallCount == 0)
//    }
//    
//    @Test func test_post_異常_routeDistrictId不一致() async throws {
//        let districtId = "district-id"
//        let route = Route(id: "route-id", districtId: "other-district-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock()
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.post(districtId: districtId, pack: route, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(routeRepositoryMock.postCallCount == 0)
//    }
//    
//    @Test func test_post_異常_routeRepositoryエラー() async throws {
//        let districtId = "district-id"
//        let route = Route(id: "route-id", districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock(postHandler: { _ in
//            throw Error.internalServerError("post_failed")
//        })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.internalServerError("post_failed")) {
//            let _ = try await subject.post(districtId: districtId, pack: route, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(routeRepositoryMock.postCallCount == 1)
//    }
//    
//    @Test func test_put_正常() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let oldRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let newRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
//        
//        var lastCalledRouteId: String? = nil
//        var lastPutRoute: Route? = nil
//        let routeRepositoryMock = RouteRepositoryMock(
//            getHandler: { id in
//                lastCalledRouteId = id
//                return oldRoute
//            },
//            putHandler: { route in
//                lastPutRoute = route
//                return route
//            }
//        )
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        let result = try await subject.put(id: routeId, pack: newRoute, user: UserRole.district(districtId))
//        
//        
//        #expect(result.start == SimpleTime(hour: 12, minute: 0))
//        #expect(lastCalledRouteId == routeId)
//        #expect(lastPutRoute?.start == SimpleTime(hour: 12, minute: 0))
//        #expect(lastPutRoute?.id == routeId)
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.putCallCount == 1)
//    }
//    
//    @Test func test_put_異常_ルートが見つからない() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        var lastCalledRouteId: String? = nil
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { id in
//            lastCalledRouteId = id
//            return nil
//        })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
//            let _ = try await subject.put(id: routeId, pack: route, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(lastCalledRouteId == routeId)
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.putCallCount == 0)
//    }
//    
//    @Test func test_put_異常_権限なし_Guest() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let route = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in route })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.put(id: routeId, pack: route, user: UserRole.guest)
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.putCallCount == 0)
//    }
//    
//    @Test func test_put_異常_routeDistrictId不一致() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let oldRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let newRoute = Route(id: routeId, districtId: "other-district-id", start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in oldRoute })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.put(id: routeId, pack: newRoute, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.putCallCount == 0)
//    }
//    
//    @Test func test_put_異常_oldDistrictId不一致() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let oldRoute = Route(id: routeId, districtId: "other-district-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let newRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in oldRoute })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.put(id: routeId, pack: newRoute, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.putCallCount == 0)
//    }
//    
//    @Test func test_put_異常_routeRepositoryエラー() async throws {
//        let routeId = "route-id"
//        let districtId = "district-id"
//        let oldRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
//        let newRoute = Route(id: routeId, districtId: districtId, start: SimpleTime(hour: 12, minute: 0), goal: SimpleTime(hour: 13, minute: 0))
//        let routeRepositoryMock = RouteRepositoryMock(
//            getHandler: { _ in oldRoute },
//            putHandler: { _ in
//                throw Error.internalServerError("put_failed")
//            }
//        )
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.internalServerError("put_failed")) {
//            let _ = try await subject.put(id: routeId, pack: newRoute, user: UserRole.district(districtId))
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.putCallCount == 1)
//    }
//
//    @Test func test_delete_正常() async throws {
//        let user = UserRole.district("d-id")
//        let expected = Route.mock()
//        var lastCalledGetId: String? = nil
//        var lastCalledDeleteId: String? = nil
//        let routeRepositoryMock = RouteRepositoryMock(
//            getHandler: { id in
//                lastCalledGetId = id
//                return expected
//            },
//            deleteHandler: { id in
//                lastCalledDeleteId = id
//                return
//            }
//        )
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        try await subject.delete(id: "route-id", user: UserRole.district("d-id"))
//        
//        
//        #expect(lastCalledGetId == "route-id")
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(lastCalledDeleteId == "route-id")
//        #expect(routeRepositoryMock.deleteCallCount == 1)
//    }
//
//    @Test func test_delete_異常_ルートが見つからない() async throws {
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in nil })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
//            let _ = try await subject.delete(id: "route-id", user: UserRole.district("d-id"))
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.deleteCallCount == 0)
//    }
//
//    @Test func test_delete_異常_ゲスト() async throws {
//        let expected = Route.mock()
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in expected })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.delete(id: "route-id", user: UserRole.guest)
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.deleteCallCount == 0)
//    }
//
//    @Test func test_delete_異常_別のDistrict() async throws {
//        let expected = Route.mock()
//        let routeRepositoryMock = RouteRepositoryMock(getHandler: { _ in expected })
//        let subject = make(routeRepository: routeRepositoryMock)
//        
//        
//        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
//            let _ = try await subject.delete(id: "route-id", user: UserRole.district("other-id"))
//        }
//        
//        
//        #expect(routeRepositoryMock.getCallCount == 1)
//        #expect(routeRepositoryMock.deleteCallCount == 0)
//    }
//}
//
//extension RouteUsecaseTest {
//    func make(
//        routeRepository: RouteRepositoryMock = .init(),
//        districtRepository: DistrictRepositoryMock = .init(),
//        locationRepository: LocationRepositoryMock = .init(),
//        festivalRepository: FestivalRepositoryMock = .init()
//    ) -> RouteUsecase {
//        let subject = withDependencies {
//            $0[RouteRepositoryKey.self] = routeRepository
//            $0[DistrictRepositoryKey.self] = districtRepository
//            $0[LocationRepositoryKey.self] = locationRepository
//            $0[FestivalRepositoryKey.self] = festivalRepository
//        } operation: {
//            RouteUsecase()
//        }
//        return subject
//    }
//}
