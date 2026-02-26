//
//  RouteInjector.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/12.
//

import Testing
@testable import Backend
import Shared
import Dependencies
import Foundation

struct RouteInjector {
    @Test(.disabled()) func inject_routes() async throws {
        let route = Route(id: UUID().uuidString, districtId: "test_district", periodId: "88B4BE1E-1A22-4313-8070-58CF320240A6", visibility: .all, description: "")
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            RouteRepository()
        }
        _ = try await subject.post(route)
    }
    
    @Test(.disabled()) func inject_points() async throws {
        let point = Point(id: UUID().uuidString, routeId: "B30822CB-62F0-4926-95B3-04145DDAA779", coordinate: .init(latitude: 0, longitude: 0), time: .now, checkpointId: nil, performanceId: nil, anchor: nil)
        let subject = withDependencies({
            $0[DataStoreFactoryKey.self] = { try! DynamoDBStore(tableName: $0) }
        }) {
            PointRepository()
        }
        _ = try await subject.post(point)
    }
    
    @Test func update_visibility() async throws {
        let districts: [District] = (try await DistrictRepository().query(by: "掛川祭_年番本部"))
        for district in districts {
            let routeRepository = RouteRepository()
            let routes = try await routeRepository.query(by: district.id)
            for route in routes {
                var updated = route
                updated.visibility = district.visibility
                try await routeRepository.put(updated)
            }
            return
        }
    }
    
    @Test(.disabled())
    func move_route() async throws {
        let routeMigrator = try DynamoDBMigrator(tableName: "matool_routes")
        let routes = try await routeMigrator.scan(Legacy.Route.self, ignoreDecodeError: false)
        let districtMigrator = try DynamoDBMigrator(tableName: "matool_districts")
        let legacyDistricts = try await districtMigrator.scan(Legacy.District.self)
        let festivalMigrator = try DynamoDBMigrator(tableName: "matool_regions")
        let legacyFestivals = try await festivalMigrator.scan(Legacy.Region.self)
        
        let districtToFestival = Dictionary(uniqueKeysWithValues: legacyDistricts.map { ($0.id, $0.regionId) })
        let performanceByDistrictAndName: [String: [String: String]] = legacyDistricts.reduce(into: [:]) { partialResult, district in
            partialResult[district.id] = district.performances.reduce(into: [:]) { map, performance in
                map[performance.name] = performance.id
            }
        }
        let checkpointByFestivalAndName: [String: [String: String]] = legacyFestivals.reduce(into: [:]) { partialResult, festival in
            partialResult[festival.id] = festival.milestones.reduce(into: [:]) { map, checkpoint in
                map[checkpoint.name] = checkpoint.id
            }
        }
        
        let periodRepository = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0) }
        }) {
            PeriodRepository()
        }
        
        let festivalIds = Set(districtToFestival.values)
        var periodsByFestival: [String: [Period]] = [:]
        for festivalId in festivalIds {
            let periods = try await periodRepository.query(by: festivalId)
            periodsByFestival[festivalId] = periods
        }
        
        var migratedRoutes: [Route] = []
        var migratedPoints: [Point] = []
        
        for route in routes {
            guard let festivalId = districtToFestival[route.districtId] else { continue }
            guard let district = legacyDistricts.first(where: { $0.id == route.districtId }) else { continue }
            guard
                let periods = periodsByFestival[festivalId],
                let periodId = nearestPeriodId(for: route, periods: periods)
            else { continue }
            
            let visibility: Shared.Visibility = {
                switch district.visibility {
                case .admin:
                    .admin
                case .route:
                    .route
                case .all:
                    .all
                }
            }()
            
            migratedRoutes.append(
                Route(
                    id: route.id,
                    districtId: route.districtId,
                    periodId: periodId,
                    visibility: visibility,
                    description: route.description
                )
            )
            
            let lastIndex = route.points.count - 1
            let checkpointMap = checkpointByFestivalAndName[festivalId] ?? [:]
            let performanceMap = performanceByDistrictAndName[route.districtId] ?? [:]
            
            for (index, point) in route.points.enumerated() {
                let mapped = mapPoint(
                    legacyPoint: point,
                    index: index,
                    lastIndex: lastIndex,
                    route: route,
                    checkpointByName: checkpointMap,
                    performanceByName: performanceMap
                )
                migratedPoints.append(
                    Point(
                        id: point.id,
                        routeId: route.id,
                        coordinate: point.coordinate,
                        time: mapped.time,
                        checkpointId: mapped.checkpointId,
                        performanceId: mapped.performanceId,
                        anchor: mapped.anchor,
                        index: index,
                        isBoundary: index == 0 || index == lastIndex
                    )
                )
            }
        }
        
        let routeRepository = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0) }
        }) {
            RouteRepository()
        }
        
        for route in migratedRoutes {
            _ = try await routeRepository.post(route)
        }
        
        let pointRepository = withDependencies({
            $0[DataStoreFactoryKey.self] = { DynamoDBStore.make(tableName: $0) }
        }) {
            PointRepository()
        }
        
        for point in migratedPoints {
            _ = try await pointRepository.post(point)
        }
    }
    
    private func mapPoint(
        legacyPoint: Legacy.Point,
        index: Int,
        lastIndex: Int,
        route: Legacy.Route,
        checkpointByName: [String: String],
        performanceByName: [String: String]
    ) -> (time: SimpleTime?, checkpointId: String?, performanceId: String?, anchor: Anchor?) {
        if index == 0 {
            return (route.start, nil, nil, .start)
        }
        
        if index == lastIndex {
            return (route.goal, nil, nil, .end)
        }
        
        let title = legacyPoint.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if title == "休憩" {
            return (legacyPoint.time, nil, nil, .rest)
        }
        
        if let title, let checkpointId = checkpointByName[title] {
            return (legacyPoint.time, checkpointId, nil, nil)
        }
        
        if let title, let performanceId = performanceByName[title] {
            return (legacyPoint.time, nil, performanceId, nil)
        }
        
        return (legacyPoint.time, nil, nil, nil)
    }
    
    private func nearestPeriodId(for route: Legacy.Route, periods: [Period]) -> String? {
        guard !periods.isEmpty else { return nil }
        
        let routeStart = Date.combine(date: route.date, time: route.start)
        return periods.min(by: { lhs, rhs in
            let lhsStart = Date.combine(date: lhs.date, time: lhs.start)
            let rhsStart = Date.combine(date: rhs.date, time: rhs.start)
            let lhsDiff = abs(lhsStart.timeIntervalSince(routeStart))
            let rhsDiff = abs(rhsStart.timeIntervalSince(routeStart))
            return lhsDiff < rhsDiff
        })?.id
    }
}
