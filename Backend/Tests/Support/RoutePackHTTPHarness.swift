import Dependencies
import Shared
@testable import Backend

struct RoutePackHTTPHarness {
    static func send(
        method: Application.Method,
        path: String,
        pack: RoutePack,
        existingRoute: Route? = nil
    ) async throws -> (Application.Response, RouteRepositoryMock, PointRepositoryMock, PassageRepositoryMock) {
        let routeRepository = RouteRepositoryMock(
            getHandler: { _ in existingRoute },
            postHandler: { $0 },
            putHandler: { $0 }
        )
        let district = District.mock(id: "district-1", festivalId: "festival-1")
        let districtRepository = DistrictRepositoryMock(getHandler: { _ in district })
        let pointRepository = PointRepositoryMock(
            queryHandler: { _ in [] },
            postHandler: { $0 },
            putHandler: { $0 }
        )
        let passageRepository = PassageRepositoryMock(
            queryHandler: { _ in [] },
            postHandler: { $0 },
            putHandler: { $0 }
        )
        let body = try pack.toString()

        let response = await withDependencies {
            $0[RouteRepositoryKey.self] = routeRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[FestivalRepositoryKey.self] = FestivalRepositoryMock()
            $0[PointRepositoryKey.self] = pointRepository
            $0[PassageRepositoryKey.self] = passageRepository
            $0[DistrictControllerKey.self] = DistrictControllerMock()
            $0[LocationControllerKey.self] = LocationControllerMock()
            $0[PeriodControllerKey.self] = PeriodControllerMock()
            $0[SceneControllerKey.self] = SceneControllerMock()
            $0[RouteUsecaseKey.self] = RouteUsecase()
            $0[RouteControllerKey.self] = RouteController()
        } operation: {
            let app = Application { DistrictRouter(); OtherRouter() }
            var request = Application.Request.make(method: method, path: path, body: body)
            request.user = .district("district-1")
            return await app.handle(request)
        }

        return (response, routeRepository, pointRepository, passageRepository)
    }
}
