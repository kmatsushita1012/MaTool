import Shared

func deleteRoutes(
    for period: Period,
    festivalId: Festival.ID,
    districtRepository: any DistrictRepositoryProtocol,
    routeRepository: any RouteRepositoryProtocol,
    pointRepository: any PointRepositoryProtocol,
    passageRepository: any PassageRepositoryProtocol
) async throws {
    // Route has no periodId index, so search each district's route partition.
    let districts = try await districtRepository.query(by: festivalId)
    for district in districts {
        let routes = try await routeRepository.query(by: district.id)
        for route in routes where route.periodId == period.id {
            try await pointRepository.delete(by: route.id)
            try await passageRepository.delete(by: route.id)
            try await routeRepository.delete(route)
        }
    }
}
