import Foundation
import Testing
import Shared
@testable import Backend

final class FestivalUsecaseMock: FestivalUsecaseProtocol, @unchecked Sendable {
    init(
        scanHandler: (() throws -> [Festival])? = nil,
        getHandler: ((String) throws -> FestivalPack)? = nil,
        putHandler: ((FestivalPack, UserRole) throws -> FestivalPack)? = nil
    ) {
        self.scanHandler = scanHandler
        self.getHandler = getHandler
        self.putHandler = putHandler
    }

    private(set) var scanCallCount = 0
    private let scanHandler: (() throws -> [Festival])?
    func scan() async throws -> [Festival] {
        scanCallCount += 1
        guard let scanHandler else { throw TestError.unimplemented }
        return try scanHandler()
    }

    private(set) var getCallCount = 0
    private let getHandler: ((String) throws -> FestivalPack)?
    func get(_ id: String) async throws -> FestivalPack {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((FestivalPack, UserRole) throws -> FestivalPack)?
    func put(_ pack: FestivalPack, user: UserRole) async throws -> FestivalPack {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(pack, user)
    }
}

final class DistrictUsecaseMock: DistrictUsecaseProtocol, @unchecked Sendable {
    init(
        queryHandler: ((String) throws -> [District])? = nil,
        getHandler: ((String) throws -> DistrictPack)? = nil,
        postHandler: ((UserRole, String, String, String) throws -> DistrictPack)? = nil,
        putPackHandler: ((String, DistrictPack, UserRole) throws -> DistrictPack)? = nil,
        putDistrictHandler: ((String, District, UserRole) throws -> District)? = nil
    ) {
        self.queryHandler = queryHandler
        self.getHandler = getHandler
        self.postHandler = postHandler
        self.putPackHandler = putPackHandler
        self.putDistrictHandler = putDistrictHandler
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) throws -> [District])?
    func query(by regionId: String) async throws -> [District] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(regionId)
    }

    private(set) var getCallCount = 0
    private let getHandler: ((String) throws -> DistrictPack)?
    func get(_ id: String) async throws -> DistrictPack {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((UserRole, String, String, String) throws -> DistrictPack)?
    func post(user: UserRole, headquarterId: String, newDistrictName: String, email: String) async throws -> DistrictPack {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(user, headquarterId, newDistrictName, email)
    }

    private(set) var putPackCallCount = 0
    private let putPackHandler: ((String, DistrictPack, UserRole) throws -> DistrictPack)?
    func put(id: String, item: DistrictPack, user: UserRole) async throws -> DistrictPack {
        putPackCallCount += 1
        guard let putPackHandler else { throw TestError.unimplemented }
        return try putPackHandler(id, item, user)
    }

    private(set) var putDistrictCallCount = 0
    private let putDistrictHandler: ((String, District, UserRole) throws -> District)?
    func put(id: String, district: District, user: UserRole) async throws -> District {
        putDistrictCallCount += 1
        guard let putDistrictHandler else { throw TestError.unimplemented }
        return try putDistrictHandler(id, district, user)
    }
}

final class RouteUsecaseMock: RouteUsecaseProtocol, @unchecked Sendable {
    init(
        getHandler: ((String, UserRole) throws -> RoutePack)? = nil,
        queryHandler: ((String, RouteQueryType, SimpleDate, UserRole) throws -> [Route])? = nil,
        postHandler: ((String, RoutePack, UserRole) throws -> RoutePack)? = nil,
        putHandler: ((String, RoutePack, UserRole) throws -> RoutePack)? = nil,
        deleteHandler: ((String, UserRole) throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((String, UserRole) throws -> RoutePack)?
    func get(id: String, user: UserRole) async throws -> RoutePack {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id, user)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String, RouteQueryType, SimpleDate, UserRole) throws -> [Route])?
    func query(by districtId: String, type: RouteQueryType, now: SimpleDate, user: UserRole) async throws -> [Route] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(districtId, type, now, user)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((String, RoutePack, UserRole) throws -> RoutePack)?
    func post(districtId: String, pack: RoutePack, user: UserRole) async throws -> RoutePack {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(districtId, pack, user)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((String, RoutePack, UserRole) throws -> RoutePack)?
    func put(id: String, pack: RoutePack, user: UserRole) async throws -> RoutePack {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(id, pack, user)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((String, UserRole) throws -> Void)?
    func delete(id: String, user: UserRole) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try deleteHandler(id, user)
    }
}

final class LocationUsecaseMock: LocationUsecaseProtocol, @unchecked Sendable {
    init(
        queryHandler: ((String, UserRole, Date) throws -> [FloatLocation])? = nil,
        getHandler: ((String, UserRole, Date) throws -> FloatLocation?)? = nil,
        putHandler: ((FloatLocation, UserRole) throws -> FloatLocation)? = nil,
        deleteHandler: ((String, UserRole) throws -> Void)? = nil
    ) {
        self.queryHandler = queryHandler
        self.getHandler = getHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String, UserRole, Date) throws -> [FloatLocation])?
    func query(by festivalId: String, user: UserRole, now: Date) async throws -> [FloatLocation] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(festivalId, user, now)
    }

    private(set) var getCallCount = 0
    private let getHandler: ((String, UserRole, Date) throws -> FloatLocation?)?
    func get(districtId: String, user: UserRole, now: Date) async throws -> FloatLocation? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(districtId, user, now)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((FloatLocation, UserRole) throws -> FloatLocation)?
    func put(_ location: FloatLocation, user: UserRole) async throws -> FloatLocation {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(location, user)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((String, UserRole) throws -> Void)?
    func delete(districtId: String, user: UserRole) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try deleteHandler(districtId, user)
    }
}

final class PeriodUsecaseMock: PeriodUsecaseProtocol, @unchecked Sendable {
    init(
        getHandler: ((String) throws -> Period)? = nil,
        queryByYearHandler: ((String, Int) throws -> [Period])? = nil,
        queryHandler: ((String) throws -> [Period])? = nil,
        postHandler: ((String, Period, UserRole) throws -> Period)? = nil,
        putHandler: ((Period, UserRole) throws -> Period)? = nil,
        deleteHandler: ((String, UserRole) throws -> Void)? = nil
    ) {
        self.getHandler = getHandler
        self.queryByYearHandler = queryByYearHandler
        self.queryHandler = queryHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var getCallCount = 0
    private let getHandler: ((String) throws -> Period)?
    func get(id: String) async throws -> Period {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id)
    }

    private(set) var queryByYearCallCount = 0
    private let queryByYearHandler: ((String, Int) throws -> [Period])?
    func query(by festivalId: String, year: Int) async throws -> [Period] {
        queryByYearCallCount += 1
        guard let queryByYearHandler else { throw TestError.unimplemented }
        return try queryByYearHandler(festivalId, year)
    }

    private(set) var queryCallCount = 0
    private let queryHandler: ((String) throws -> [Period])?
    func query(by festivalId: String) async throws -> [Period] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(festivalId)
    }

    private(set) var postCallCount = 0
    private let postHandler: ((String, Period, UserRole) throws -> Period)?
    func post(festivalId: String, period: Period, user: UserRole) async throws -> Period {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(festivalId, period, user)
    }

    private(set) var putCallCount = 0
    private let putHandler: ((Period, UserRole) throws -> Period)?
    func put(period: Period, user: UserRole) async throws -> Period {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(period, user)
    }

    private(set) var deleteCallCount = 0
    private let deleteHandler: ((String, UserRole) throws -> Void)?
    func delete(id: String, user: UserRole) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try deleteHandler(id, user)
    }
}

final class SceneUsecaseMock: SceneUsecaseProtocol, @unchecked Sendable {
    init(
        fetchLaunchFestivalByFestivalIdHandler: ((String, UserRole, Date) throws -> LaunchFestivalPack)? = nil,
        fetchLaunchFestivalByDistrictIdHandler: ((String, UserRole, Date) throws -> LaunchFestivalPack)? = nil,
        fetchLaunchDistrictHandler: ((String, UserRole, Date) throws -> LaunchDistrictPack)? = nil
    ) {
        self.fetchLaunchFestivalByFestivalIdHandler = fetchLaunchFestivalByFestivalIdHandler
        self.fetchLaunchFestivalByDistrictIdHandler = fetchLaunchFestivalByDistrictIdHandler
        self.fetchLaunchDistrictHandler = fetchLaunchDistrictHandler
    }

    private(set) var fetchLaunchFestivalByFestivalIdCallCount = 0
    private let fetchLaunchFestivalByFestivalIdHandler: ((String, UserRole, Date) throws -> LaunchFestivalPack)?
    func fetchLaunchFestivalPack(festivalId: String, user: UserRole, now: Date) async throws -> LaunchFestivalPack {
        fetchLaunchFestivalByFestivalIdCallCount += 1
        guard let fetchLaunchFestivalByFestivalIdHandler else { throw TestError.unimplemented }
        return try fetchLaunchFestivalByFestivalIdHandler(festivalId, user, now)
    }

    private(set) var fetchLaunchFestivalByDistrictIdCallCount = 0
    private let fetchLaunchFestivalByDistrictIdHandler: ((String, UserRole, Date) throws -> LaunchFestivalPack)?
    func fetchLaunchFestivalPack(districtId: String, user: UserRole, now: Date) async throws -> LaunchFestivalPack {
        fetchLaunchFestivalByDistrictIdCallCount += 1
        guard let fetchLaunchFestivalByDistrictIdHandler else { throw TestError.unimplemented }
        return try fetchLaunchFestivalByDistrictIdHandler(districtId, user, now)
    }

    private(set) var fetchLaunchDistrictCallCount = 0
    private let fetchLaunchDistrictHandler: ((String, UserRole, Date) throws -> LaunchDistrictPack)?
    func fetchLaunchDistrictPack(districtId: String, user: UserRole, now: Date) async throws -> LaunchDistrictPack {
        fetchLaunchDistrictCallCount += 1
        guard let fetchLaunchDistrictHandler else { throw TestError.unimplemented }
        return try fetchLaunchDistrictHandler(districtId, user, now)
    }
}
