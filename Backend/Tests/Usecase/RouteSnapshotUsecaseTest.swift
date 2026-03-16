import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct RouteSnapshotUsecaseTest {
    @Test
    func get_正常_ルート存在時にPNGペイロードを返す() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let repository = RouteRepositoryMock(getHandler: { _ in route })
        let pointRepository = PointRepositoryMock(queryHandler: { _ in [.mock(routeId: route.id)] })
        let renderer = RouteSnapshotRendererMock(renderPNGHandler: { _, _ in Data("png".utf8) })

        let subject = withDependencies {
            $0[RouteRepositoryKey.self] = repository
            $0[PointRepositoryKey.self] = pointRepository
            $0[RouteSnapshotRendererKey.self] = renderer
        } operation: {
            RouteSnapshotUsecase()
        }

        let result = try await subject.get(routeId: route.id)

        #expect(result.contentType == "image/png")
        #expect(result.base64Body == Data("png".utf8).base64EncodedString())
        #expect(repository.getCallCount == 1)
        #expect(pointRepository.queryCallCount == 1)
        #expect(renderer.renderPNGCallCount == 1)
    }

    @Test
    func get_異常_ルート未存在はnotFound() async {
        let repository = RouteRepositoryMock(getHandler: { _ in nil })

        let subject = withDependencies {
            $0[RouteRepositoryKey.self] = repository
        } operation: {
            RouteSnapshotUsecase()
        }

        await #expect(throws: Error.notFound("指定されたルートが見つかりません")) {
            _ = try await subject.get(routeId: "missing")
        }
    }

    @Test
    func post_正常_RoutePack入力でPNGペイロードを返す() async throws {
        let renderer = RouteSnapshotRendererMock(renderPNGHandler: { _, _ in Data("png".utf8) })
        let pack = RoutePack.mock(
            route: .mock(id: "route-1", districtId: "district-1"),
            points: [.mock(routeId: "route-1")]
        )
        let subject = withDependencies {
            $0[RouteSnapshotRendererKey.self] = renderer
        } operation: {
            RouteSnapshotUsecase()
        }

        let result = try await subject.post(routePack: pack)

        #expect(result.contentType == "image/png")
        #expect(result.base64Body == Data("png".utf8).base64EncodedString())
        #expect(renderer.renderPNGCallCount == 1)
    }

    @Test
    func postDistrict_正常_年指定でPDFを返す() async throws {
        let repository = RouteRepositoryMock(queryByYearHandler: { _, _ in
            [.mock(id: "route-1", districtId: "district-1")]
        })
        let pointRepository = PointRepositoryMock(queryHandler: { _ in [.mock(routeId: "route-1")] })
        let renderer = RouteSnapshotRendererMock(renderPDFHandler: { pages in
            #expect(pages.count == 1)
            #expect(pages[0].routeId == "route-1")
            return Data("pdf".utf8)
        })
        let subject = withDependencies {
            $0[RouteRepositoryKey.self] = repository
            $0[PointRepositoryKey.self] = pointRepository
            $0[RouteSnapshotRendererKey.self] = renderer
        } operation: {
            RouteSnapshotUsecase()
        }

        let result = try await subject.postDistrict(districtId: "district-1", year: "2026")

        #expect(result.contentType == "application/pdf")
        #expect(result.base64Body == Data("pdf".utf8).base64EncodedString())
        #expect(repository.queryByYearCallCount == 1)
        #expect(pointRepository.queryCallCount == 1)
        #expect(renderer.renderPDFCallCount == 1)
    }

    @Test
    func postDistrict_異常_対象なしはnotFound() async {
        let repository = RouteRepositoryMock(queryByYearHandler: { _, _ in [] })
        let subject = withDependencies {
            $0[RouteRepositoryKey.self] = repository
        } operation: {
            RouteSnapshotUsecase()
        }

        await #expect(throws: Error.notFound("指定された条件でルートが見つかりません")) {
            _ = try await subject.postDistrict(districtId: "district-1", year: "2026")
        }
    }
}
