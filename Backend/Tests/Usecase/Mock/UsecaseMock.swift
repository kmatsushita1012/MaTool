//
//  UsecaseMock.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

import Testing
@testable import Backend
import Shared
import Foundation

final class FestivalUsecaseMock: FestivalUsecaseProtocol, @unchecked Sendable {

    init(scanCallCount: Int = 0, scanHandler: (() throws -> [Festival])? = nil, getCallCount: Int = 0, getHandler: ((String) throws -> Shared.FestivalPack)? = nil, putCallCount: Int = 0, putHandler: ((Shared.FestivalPack, Shared.UserRole) throws -> Shared.FestivalPack)? = nil) {
        self.scanCallCount = scanCallCount
        self.scanHandler = scanHandler
        self.getCallCount = getCallCount
        self.getHandler = getHandler
        self.putCallCount = putCallCount
        self.putHandler = putHandler
    }
    
    private(set) var scanCallCount = 0
    private var scanHandler: (() throws -> [Festival])? = nil
    func scan() async throws -> [Festival] {
        scanCallCount+=1
        guard let scanHandler else { fatalError("Unimplemented") }
        return try scanHandler()
    }
    
    private(set) var getCallCount = 0
    private var getHandler: ((String) throws -> Shared.FestivalPack)? = nil
    func get(_ id: String) async throws -> Shared.FestivalPack {
        getCallCount+=1
        guard let getHandler else { fatalError("Unimplemented")}
        return try getHandler(id)
    }
    
    private(set) var putCallCount = 0
    private var putHandler: ((Shared.FestivalPack, Shared.UserRole) throws -> Shared.FestivalPack)? = nil
    func put(_ festival: Shared.FestivalPack, user: Shared.UserRole) async throws -> Shared.FestivalPack {
        putCallCount+=1
        guard let putHandler else { fatalError("Unimplemented")}
        return try putHandler(festival, user)
    }
}

final class DistrictUsecaseMock: DistrictUsecaseProtocol, @unchecked Sendable {
    
    init(
        queryHandler: ((String) throws -> [Shared.District])? = nil,
        getHandler: ((String) throws -> Shared.DistrictPack)? = nil,
        postHandler: ((Shared.UserRole, String, String, String) throws -> Shared.DistrictPack)? = nil,
        putHandler: ((String, Shared.DistrictPack, Shared.UserRole) throws -> Shared.DistrictPack)? = nil
    ) {
        self.queryHandler = queryHandler
        self.getHandler = getHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
    }

    private(set) var queryCallCount = 0
    private var queryHandler: ((String) throws -> [Shared.District])? = nil
    func query(by regionId: String) async throws -> [Shared.District] {
        queryCallCount += 1
        guard let queryHandler else { fatalError("Unimplemented") }
        return try queryHandler(regionId)
    }

    private(set) var getCallCount = 0
    private var getHandler: ((String) throws -> Shared.DistrictPack)? = nil
    func get(_ id: String) async throws -> Shared.DistrictPack {
        getCallCount += 1
        guard let getHandler else { fatalError("Unimplemented") }
        return try getHandler(id)
    }

    private(set) var postCallCount = 0
    private var postHandler: ((Shared.UserRole, String, String, String) throws -> Shared.DistrictPack)? = nil
    func post(user: Shared.UserRole, headquarterId: String, newDistrictName: String, email: String) async throws -> Shared.DistrictPack {
        postCallCount += 1
        guard let postHandler else { fatalError("Unimplemented") }
        return try postHandler(user, headquarterId, newDistrictName, email)
    }

    private(set) var putCallCount = 0
    private var putHandler: ((String, Shared.DistrictPack, Shared.UserRole) throws -> Shared.DistrictPack)? = nil
    func put(id: String, item: Shared.DistrictPack, user: Shared.UserRole) async throws -> Shared.DistrictPack {
        putCallCount += 1
        guard let putHandler else { fatalError("Unimplemented") }
        return try putHandler(id, item, user)
    }
    
    func put(id: String, district: Shared.District, user: Shared.UserRole) async throws -> Shared.District {
        throw TestError.unimplemented
    }
    
}

final class RouteUsecaseMock: RouteUsecaseProtocol, @unchecked Sendable {
    init(
        queryHandler: ((String, UserRole) throws -> [Shared.Route])? = nil,
        getHandler: ((String, UserRole) throws -> Shared.RouteDetailPack)? = nil,
        postHandler: ((String, Shared.RouteDetailPack, Shared.UserRole) throws -> Shared.RouteDetailPack)? = nil,
        putHandler: ((String, Shared.RouteDetailPack, Shared.UserRole) throws -> Shared.RouteDetailPack)? = nil,
        deleteHandler: ((String, Shared.UserRole) throws -> Void)? = nil,
        getAllRouteIdsHandler: ((Shared.UserRole) throws -> [String])? = nil
    ) {
        self.queryHandler = queryHandler
        self.getHandler = getHandler
        self.postHandler = postHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
        self.getAllRouteIdsHandler = getAllRouteIdsHandler
    }

    private(set) var queryCallCount = 0
    private var queryHandler: ((String, UserRole) throws -> [Shared.Route])? = nil
    func query(by districtId: String, type: Backend.RouteQueryType, now: Shared.SimpleDate, user: Shared.UserRole) async throws -> [Shared.Route] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(districtId, user)
    }
    
    private(set) var getCallCount = 0
    private var getHandler: ((String, UserRole) throws -> Shared.RouteDetailPack)? = nil
    func get(id: String, user: UserRole) async throws -> Shared.RouteDetailPack {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(id, user)
    }
    private(set) var postCallCount = 0
    private var postHandler: ((String, Shared.RouteDetailPack, Shared.UserRole) throws -> Shared.RouteDetailPack)? = nil
    func post(districtId: String, pack: Shared.RouteDetailPack, user: Shared.UserRole) async throws -> Shared.RouteDetailPack {
        postCallCount += 1
        guard let postHandler else { throw TestError.unimplemented }
        return try postHandler(districtId, pack, user)
    }

    private(set) var putCallCount = 0
    private var putHandler: ((String, Shared.RouteDetailPack, Shared.UserRole) throws -> Shared.RouteDetailPack)? = nil
    func put(id: String, pack: Shared.RouteDetailPack, user: Shared.UserRole) async throws -> Shared.RouteDetailPack {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(id, pack, user)
    }
    
    private(set) var deleteCallCount = 0
    private var deleteHandler: ((String, Shared.UserRole) throws -> Void )? = nil
    func delete(id: String, user: Shared.UserRole) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try deleteHandler(id, user)
        return
    }

    private(set) var getAllRouteIdsCallCount = 0
    private var getAllRouteIdsHandler: ((Shared.UserRole) throws -> [String])? = nil
    func getAllRouteIds(user: Shared.UserRole) async throws -> [String] {
        getAllRouteIdsCallCount += 1
        guard let getAllRouteIdsHandler else { throw TestError.unimplemented }
        return try getAllRouteIdsHandler(user)
    }
}

final class LocationUsecaseMock: LocationUsecaseProtocol, @unchecked Sendable {
    
    
    init(
        queryHandler: ((String, UserRole, Date) throws -> [Shared.FloatLocation])? = nil,
        getHandler: ((String, UserRole) throws -> Shared.FloatLocation)? = nil,
        putHandler: ((Shared.FloatLocation, Shared.UserRole) throws -> Shared.FloatLocation)? = nil,
        deleteHandler: ((String, Shared.UserRole) throws -> Void)? = nil
    ) {
        self.queryHandler = queryHandler
        self.getHandler = getHandler
        self.putHandler = putHandler
        self.deleteHandler = deleteHandler
    }

    private(set) var queryCallCount = 0
    private var queryHandler: ((String, UserRole, Date) throws -> [Shared.FloatLocation])? = nil
    func  query(by festivalId: String, user: Shared.UserRole, now: Date) async throws -> [Shared.FloatLocation] {
        queryCallCount += 1
        guard let queryHandler else { throw TestError.unimplemented }
        return try queryHandler(festivalId, user, now)
    }

    private(set) var getCallCount = 0
    private var getHandler: ((String, UserRole) throws -> Shared.FloatLocation)? = nil
    func get(districtId: String, user: Shared.UserRole, now: Date) async throws -> Shared.FloatLocation? {
        getCallCount += 1
        guard let getHandler else { throw TestError.unimplemented }
        return try getHandler(districtId, user)
    }

    private(set) var putCallCount = 0
    private var putHandler: ((Shared.FloatLocation, Shared.UserRole) throws -> Shared.FloatLocation)? = nil
    func put(_ location: Shared.FloatLocation, user: Shared.UserRole) async throws -> Shared.FloatLocation {
        putCallCount += 1
        guard let putHandler else { throw TestError.unimplemented }
        return try putHandler(location, user)
    }

    private(set) var deleteCallCount = 0
    private var deleteHandler: ((String, Shared.UserRole) throws -> Void)? = nil
    func delete(districtId id: String, user: Shared.UserRole) async throws {
        deleteCallCount += 1
        guard let deleteHandler else { throw TestError.unimplemented }
        try deleteHandler(id, user)
        return
    }
}
