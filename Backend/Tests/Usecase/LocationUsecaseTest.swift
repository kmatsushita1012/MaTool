import Foundation
import Testing
@testable import Backend
import Dependencies
import Shared

struct LocationUsecaseTest {
    
    let festival = Festival.mock()
    let district = District.mock()
    let location = FloatLocation.mock()
    let locations = [FloatLocation.mock()]
    
    
    @Test func test_query_admin_success() async throws {
        var districtLastCalledId: String?
        var festivalLastCalledId: String?
        let districtRepositoryMock = DistrictRepositoryMock(queryHandler: { id in
            districtLastCalledId = id
            return [district]
        })
        let locationRepositoryMock = LocationRepositoryMock(queryHandler: { _ in locations })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { id in
            festivalLastCalledId = id
            return festival
        })
        let subject = make( districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock, festivalRepository: festivalRepositoryMock)
        
        
        let result = try await subject.query(by: "festival-id", user: .headquarter("festival-id"), now: Date())
        
        
        #expect(districtRepositoryMock.queryCallCount == 1)
        #expect(districtLastCalledId == "festival-id")
        #expect(locationRepositoryMock.queryCallCount == 1)
        #expect(festivalRepositoryMock.getCallCount == 0)
        #expect(festivalLastCalledId == nil)
        #expect(result == locations)
    }
    
    @Test(.disabled())
    func test_query_public_success_with_period() async throws {
        var festivalLastCalledId: String? = nil
        var districtLastCalledId: String? = nil
        
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { id in
            festivalLastCalledId = id
            return festival
        })
        let districtRepositoryMock = DistrictRepositoryMock(queryHandler: { id in
            districtLastCalledId = id
            return [district]
        })
        let locationRepositoryMock = LocationRepositoryMock(queryHandler: { _ in locations })
        
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock, festivalRepository: festivalRepositoryMock)
        
        let result = try await subject.query(by: festival.id, user: .guest, now: Date())
        
        #expect(result == locations)
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(festivalLastCalledId == festival.id)
        #expect(districtRepositoryMock.queryCallCount == 1)
        #expect(districtLastCalledId == festival.id)
        #expect(locationRepositoryMock.queryCallCount == 1)
    }
    
    @Test func test_query_public_out_of_period_returns_empty() async throws {
        var festivalLastCalledId: String? = nil
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { id in
            festivalLastCalledId = id
            return festival
        })
        
        let subject = make( festivalRepository: festivalRepositoryMock)
        
        await #expect(throws: Error.forbidden("祭典期間外のため配信を停止しています。") ) {
            let _ = try await subject.query(by: "festival-id", user: .guest, now: Date().addingTimeInterval(7200))
        }
        
        
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(festivalLastCalledId == festival.id)
    }
    
    @Test func test_query_festival_not_found_throws() async throws {
        let festivalId = "fest-1"
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in nil })
        let subject = make(festivalRepository: festivalRepositoryMock)
        
        await #expect(throws: Error.notFound("指定された地域が見つかりません")) {
            let _ = try await subject.query(by: festivalId, user: .guest, now: Date())
        }
        
        #expect(festivalRepositoryMock.getCallCount == 1)
    }
    
    @Test(.disabled())
    func test_query_districts_not_found_throws() async throws {
        var festivalLastCalledId: String? = nil
        var districtLastCalledId: String? = nil
        
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { id in
            festivalLastCalledId = id
            return festival
        })
        let districtRepositoryMock = DistrictRepositoryMock(queryHandler: { id in
            districtLastCalledId = id
            return []
        })
        let locationRepositoryMock = LocationRepositoryMock(queryHandler: { _ in locations })
        
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock, festivalRepository: festivalRepositoryMock)
        
        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            let _ = try await subject.query(by: festival.id, user: .guest, now: Date())
        }
        
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(festivalLastCalledId == festival.id)
        #expect(districtRepositoryMock.queryCallCount == 1)
        #expect(districtLastCalledId == festival.id)
    }
    
    // --- get (single) tests
    @Test func test_get_admin_headquarter_success() async throws {
        
        var lastCalledDistrictId: String? = nil
        var lastCalledLocationId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { id, _  in
            lastCalledLocationId = id
            return location
        })
        
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock)
        
        let result = try await subject.get(districtId: "district-id", user: .headquarter("festival-id"), now: .now)
        
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(lastCalledDistrictId == "district-id")
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(lastCalledLocationId == "district-id")
        #expect(result == location)
    }
    
    @Test func test_get_admin_district_success() async throws {
        
        var lastCalledDistrictId: String? = nil
        var lastCalledLocationId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { id, _  in
            lastCalledLocationId = id
            return location
        })
        
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock)
        
        
        let result = try await subject.get(districtId: "district-id", user: .district("district-id"), now: .now)
        
        
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(lastCalledDistrictId == "district-id")
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(lastCalledLocationId == "district-id")
        #expect(result == location)
    }
    
    @Test(.disabled()) func test_get_public_within_period_success() async throws {
        var lastCalledDistrictId: String? = nil
        var lastCalledFestivalId: String? = nil
        var lastCalledLocationId: String? = nil
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { id in
            lastCalledDistrictId = id
            return district
        })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { id in
            lastCalledFestivalId = id
            return festival
        })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { id, _  in
            lastCalledLocationId = id
            return location
        })
        
        
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock, festivalRepository: festivalRepositoryMock)
        
        
        let result = try await subject.get(districtId: "district-id", user: .guest, now: .now)
        
        
        #expect(result == location)
        #expect(festivalRepositoryMock.getCallCount == 1)
        #expect(lastCalledFestivalId == festival.id)
        #expect(districtRepositoryMock.getCallCount == 1)
        #expect(lastCalledDistrictId == "district-id")
        #expect(locationRepositoryMock.getCallCount == 1)
        #expect(lastCalledLocationId == "district-id")
    }
    
    @Test func test_get_district_not_found_throws() async throws {
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in nil })
        let subject = make(districtRepository: districtRepositoryMock)
        
        await #expect(throws: Error.notFound("指定された地区が見つかりません")) {
            let _ = try await subject.get(districtId: "districtId", user: .guest, now: .now)
        }
    }
    
    @Test func test_get_festival_not_found_throws() async throws {
        let districtId = "districtId"
        let district = District(id: districtId, name: "district-name", festivalId: "fest-1", visibility: .all)
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in nil })
        
        let subject = make(districtRepository: districtRepositoryMock, festivalRepository: festivalRepositoryMock)
        
        await #expect(throws: Error.notFound("指定された地域が見つかりません")) {
            let _ = try await subject.get(districtId: districtId, user: .guest, now: .now)
        }
    }
    
    @Test func test_get_public_out_of_period_throws() async throws {
        let districtId = "districtId"
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in festival })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _,_  in location })
        
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock, festivalRepository: festivalRepositoryMock)
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.get(districtId: districtId, user: .guest, now: .now)
        }
    }
    
    @Test(.disabled())
    func test_get_location_not_found_throws() async throws {
        
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in district })
        let festivalRepositoryMock = FestivalRepositoryMock(getHandler: { _ in festival })
        let locationRepositoryMock = LocationRepositoryMock(getHandler: { _,_  in nil })
        
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock, festivalRepository: festivalRepositoryMock)
        
        await #expect(throws: Error.notFound("位置情報が見つかりません")) {
            let _ = try await subject.get(districtId: "d-id", user: .guest, now: .now)
        }
    }
    
    // --- put tests
    @Test func test_put_success() async throws {
        var lastCalledLocation: FloatLocation? = nil
        
        let locationRepositoryMock = LocationRepositoryMock(putHandler: { location, _  in
            lastCalledLocation = location
            return location
        })
        let subject = make(locationRepository: locationRepositoryMock)
        
        
        let result = try await subject.put(location, user: .district("district-id"))
        
        
        #expect(locationRepositoryMock.putCallCount == 1)
        #expect(lastCalledLocation == location)
        #expect(result == location)
    }
    
    @Test func test_put_unauthorized_guest() async throws {
        let districtId = "districtId"

        let locationRepositoryMock = LocationRepositoryMock()
        let subject = make(districtRepository: .init(getHandler: { _ in district }), locationRepository: locationRepositoryMock)
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.put(location, user: .guest)
        }
        
        #expect(locationRepositoryMock.putCallCount == 0)
    }
    
    @Test func test_put_unauthorized_mismatch() async throws {
        let districtId = "districtId"
        
        let locationRepositoryMock = LocationRepositoryMock()
        let subject = make(districtRepository: .init(getHandler: { _ in .mock() }), locationRepository: locationRepositoryMock)
        
        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.put(location, user: .district("other"))
        }
        
        #expect(locationRepositoryMock.putCallCount == 0)
    }
    
    @Test func test_delete_success() async throws {
        var lastCalledId: String? = nil
        
        let locationRepositoryMock = LocationRepositoryMock(deleteHandler: { id, _  in
            lastCalledId = id
        })
        
        let subject = make(locationRepository: locationRepositoryMock)
        
        
        try await subject.delete(districtId: "district-id", user: .district("district-id"))

        
        #expect(lastCalledId == "district-id")
        #expect(locationRepositoryMock.deleteCallCount == 1)
    }

    @Test func test_delete_unauthorized_guest() async throws {
        let districtId = "d-id"
        let locationRepositoryMock = LocationRepositoryMock()
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in District(id: districtId, name: "n", festivalId: "f", visibility: .all) })
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.delete(districtId: districtId, user: .guest)
        }

        #expect(districtRepositoryMock.getCallCount == 0)
        #expect(locationRepositoryMock.deleteCallCount == 0)
    }

    @Test func test_delete_unauthorized_other_district() async throws {
        let districtId = "d-id"
        let locationRepositoryMock = LocationRepositoryMock()
        let districtRepositoryMock = DistrictRepositoryMock(getHandler: { _ in District(id: districtId, name: "n", festivalId: "f", visibility: .all) })
        let subject = make(districtRepository: districtRepositoryMock, locationRepository: locationRepositoryMock)

        await #expect(throws: Error.unauthorized("アクセス権限がありません")) {
            let _ = try await subject.delete(districtId: districtId, user: .district("other"))
        }

        #expect(districtRepositoryMock.getCallCount == 0)
        #expect(locationRepositoryMock.deleteCallCount == 0)
    }

    @Test func test_delete_repository_error_bubbles() async throws {
        let locationRepositoryMock = LocationRepositoryMock(deleteHandler: { _,_  in
            throw Error.internalServerError("delete_failed")
        })
        let subject = make(locationRepository: locationRepositoryMock)

        
        await #expect(throws: Error.internalServerError("delete_failed")) {
            let _ = try await subject.delete(districtId: "district-id", user: .district("district-id"))
        }

        
        #expect(locationRepositoryMock.deleteCallCount == 1)
    }
}

extension LocationUsecaseTest {
    func make(
        routeRepository: RouteRepositoryMock = .init(),
        districtRepository: DistrictRepositoryMock = .init(),
        locationRepository: LocationRepositoryMock = .init(),
        festivalRepository: FestivalRepositoryMock = .init()
    ) -> LocationUsecase {
        let subject = withDependencies {
            $0[RouteRepositoryKey.self] = routeRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[LocationRepositoryKey.self] = locationRepository
            $0[FestivalRepositoryKey.self] = festivalRepository
        } operation: {
            LocationUsecase()
        }
        return subject
    }
}
