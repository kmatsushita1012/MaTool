import Dependencies
import Shared
import Testing
@testable import Backend

struct RouteSnapshotUsecaseTest {
    @Test
    func get_正常_ルート存在時にPNGペイロードを返す() async throws {
        let route = Route.mock(id: "route-1", districtId: "district-1")
        let repository = RouteRepositoryMock(getHandler: { _ in route })

        let subject = withDependencies {
            $0[RouteRepositoryKey.self] = repository
        } operation: {
            RouteSnapshotUsecase()
        }

        let result = try await subject.get(routeId: route.id)

        #expect(result.contentType == "image/png")
        #expect(result.base64Body.isEmpty == false)
        #expect(repository.getCallCount == 1)
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
}
