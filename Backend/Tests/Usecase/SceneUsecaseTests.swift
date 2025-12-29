import Dependencies
import Foundation
import Testing
import Shared
@testable import Backend

struct SceneUsecaseTests {
}

extension SceneUsecaseTests {
    func make(
        routeRepository: RouteRepositoryMock = .init(),
        districtRepository: DistrictRepositoryMock = .init(),
        periodRepository: PeriodRepositoryMock = .init(),
        locationRepository: LocationRepositoryMock = .init(),
        festivalRepository: FestivalRepositoryMock = .init()
    ) -> SceneUsecase {
        let subject = withDependencies {
            $0[RouteRepositoryKey.self] = routeRepository
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PeriodRepositoryKey.self] = periodRepository
            $0[LocationRepositoryKey.self] = locationRepository
            $0[FestivalRepositoryKey.self] = festivalRepository
        } operation: {
            SceneUsecase()
        }
        return subject
    }
}

