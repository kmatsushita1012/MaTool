import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

@Suite(.serialized)
struct DistrictPackScopeHTTPTest {
    @Test
    func put_異常_別地区の演舞を含むパックは400で永続データを変更しない() async throws {
        let ownerDistrictID = "district-owner"
        let foreignDistrictID = "district-other"
        let originalDistrict = District.mock(id: ownerDistrictID, festivalId: "festival-1")
        let originalPerformance = Performance.mock(id: "performance-owner", districtId: ownerDistrictID)
        let foreignPerformance = Performance.mock(id: "performance-other", districtId: foreignDistrictID)
        var persistedDistrict = originalDistrict
        var persistedPerformances = [
            originalPerformance.id: originalPerformance,
            foreignPerformance.id: foreignPerformance,
        ]

        let districtRepository = DistrictRepositoryMock(
            getHandler: { id in id == ownerDistrictID ? persistedDistrict : nil },
            putHandler: { _, item in
                persistedDistrict = item
                return item
            }
        )
        let performanceRepository = PerformanceRepositoryMock(
            queryHandler: { districtID in
                persistedPerformances.values.filter { $0.districtId == districtID }
            },
            postHandler: { item in
                persistedPerformances[item.id] = item
                return item
            },
            putHandler: { item in
                persistedPerformances[item.id] = item
                return item
            },
            deleteHandler: { item in
                persistedPerformances[item.id] = nil
            }
        )
        let incoming = DistrictPack(
            district: .mock(id: ownerDistrictID, festivalId: "festival-1", name: "changed"),
            performances: [foreignPerformance]
        )
        var request = Application.Request.make(
            method: .put,
            path: "/districts/\(ownerDistrictID)",
            body: try incoming.toString()
        )
        request.user = .district(ownerDistrictID)

        let response = await handle(
            request,
            districtRepository: districtRepository,
            performanceRepository: performanceRepository
        )
        let error = try JSONDecoder().decode(ErrorResponse.self, from: Data(response.body.utf8))

        #expect(response.statusCode == 400)
        #expect(error.localizedDescription == "演舞データに別地区の演舞が含まれています。")
        #expect(districtRepository.getCallCount == 0)
        #expect(districtRepository.putCallCount == 0)
        #expect(performanceRepository.queryCallCount == 0)
        #expect(performanceRepository.postCallCount == 0)
        #expect(performanceRepository.putCallCount == 0)
        #expect(performanceRepository.deleteCallCount == 0)
        #expect(persistedDistrict == originalDistrict)
        #expect(persistedPerformances[originalPerformance.id] == originalPerformance)
        #expect(persistedPerformances[foreignPerformance.id] == foreignPerformance)
    }

    @Test
    func put_正常_同地区の演舞は更新できる() async throws {
        let districtID = "district-owner"
        let originalDistrict = District.mock(id: districtID, festivalId: "festival-1")
        let originalPerformance = Performance.mock(id: "performance-1", districtId: districtID)
        let updatedPerformance = Performance.mock(
            id: originalPerformance.id,
            districtId: districtID,
            name: "updated"
        )
        var persistedDistrict = originalDistrict
        var persistedPerformances = [originalPerformance.id: originalPerformance]

        let districtRepository = DistrictRepositoryMock(
            getHandler: { id in id == districtID ? persistedDistrict : nil },
            putHandler: { _, item in
                persistedDistrict = item
                return item
            }
        )
        let performanceRepository = PerformanceRepositoryMock(
            queryHandler: { requestedDistrictID in
                persistedPerformances.values.filter { $0.districtId == requestedDistrictID }
            },
            putHandler: { item in
                persistedPerformances[item.id] = item
                return item
            }
        )
        let incoming = DistrictPack(
            district: .mock(id: districtID, festivalId: "festival-1", name: "updated district"),
            performances: [updatedPerformance]
        )
        var request = Application.Request.make(
            method: .put,
            path: "/districts/\(districtID)",
            body: try incoming.toString()
        )
        request.user = .district(districtID)

        let response = await handle(
            request,
            districtRepository: districtRepository,
            performanceRepository: performanceRepository
        )
        let pack = try DistrictPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(pack.district.name == "updated district")
        #expect(pack.performances == [updatedPerformance])
        #expect(persistedDistrict.name == "updated district")
        #expect(persistedPerformances[originalPerformance.id] == updatedPerformance)
        #expect(districtRepository.putCallCount == 1)
        #expect(performanceRepository.queryCallCount == 1)
        #expect(performanceRepository.putCallCount == 1)
    }
}

private extension DistrictPackScopeHTTPTest {
    func handle(
        _ request: Application.Request,
        districtRepository: DistrictRepositoryMock,
        performanceRepository: PerformanceRepositoryMock
    ) async -> Application.Response {
        await withDependencies {
            $0[DistrictRepositoryKey.self] = districtRepository
            $0[PerformanceRepositoryKey.self] = performanceRepository
            $0[RouteRepositoryKey.self] = RouteRepositoryMock()
            $0[PeriodRepositoryKey.self] = PeriodRepositoryMock()
            $0[FestivalRepositoryKey.self] = FestivalRepositoryMock()
            $0[DistrictUsecaseKey.self] = DistrictUsecase()
            $0[DistrictControllerKey.self] = DistrictController()
            $0[RouteControllerKey.self] = RouteControllerMock()
            $0[LocationControllerKey.self] = LocationControllerMock()
            $0[SceneControllerKey.self] = SceneControllerMock()
        } operation: {
            await Application { DistrictRouter() }.handle(request)
        }
    }
}
