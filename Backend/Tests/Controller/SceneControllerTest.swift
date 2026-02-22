import Dependencies
import Shared
import Testing
@testable import Backend

struct SceneControllerTest {
    @Test
    func launchFestival_正常_条件1() async throws {
        let expected = LaunchFestivalPack.mock(festival: .mock(id: "festival-1"))
        var lastCalledFestivalId: String?
        var lastCalledUser: UserRole?

        let mock = SceneUsecaseMock(
            fetchLaunchFestivalByFestivalIdHandler: { festivalId, user, _ in
                lastCalledFestivalId = festivalId
                lastCalledUser = user
                return expected
            }
        )
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .get,
            path: "/festivals/festival-1/launch",
            parameters: ["festivalId": "festival-1"]
        )

        let response = try await subject.launchFestival(request, next: next)
        let actual = try LaunchFestivalPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(lastCalledFestivalId == "festival-1")
        #expect(lastCalledUser == .guest)
        #expect(mock.fetchLaunchFestivalByFestivalIdCallCount == 1)
    }

    @Test
    func launchFestival_正常_条件2() async throws {
        let expected = LaunchFestivalPack.mock(festival: .mock(id: "festival-1"))
        var lastCalledDistrictId: String?

        let mock = SceneUsecaseMock(
            fetchLaunchFestivalByDistrictIdHandler: { districtId, _, _ in
                lastCalledDistrictId = districtId
                return expected
            }
        )
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .get,
            path: "/districts/district-1/launch-festival",
            parameters: ["districtId": "district-1"]
        )

        let response = try await subject.launchFestival(request, next: next)
        let actual = try LaunchFestivalPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(lastCalledDistrictId == "district-1")
        #expect(mock.fetchLaunchFestivalByDistrictIdCallCount == 1)
    }

    @Test
    func launchFestival_異常_条件() async {
        let subject = make(usecase: SceneUsecaseMock())
        let request = Application.Request.make(method: .get, path: "/launch")

        await #expect(throws: Error.badRequest("不正なリクエストです。")) {
            _ = try await subject.launchFestival(request, next: next)
        }
    }

    @Test
    func launchDistrict_正常() async throws {
        let expected = LaunchDistrictPack.mock(currentRouteId: "route-1")
        var lastCalledDistrictId: String?

        let mock = SceneUsecaseMock(fetchLaunchDistrictHandler: { districtId, _, _ in
            lastCalledDistrictId = districtId
            return expected
        })
        let subject = make(usecase: mock)

        let request = Application.Request.make(
            method: .get,
            path: "/districts/district-1/launch",
            parameters: ["districtId": "district-1"]
        )

        let response = try await subject.launchDistrict(request, next: next)
        let actual = try LaunchDistrictPack.from(response.body)

        #expect(response.statusCode == 200)
        #expect(actual == expected)
        #expect(lastCalledDistrictId == "district-1")
        #expect(mock.fetchLaunchDistrictCallCount == 1)
    }
}

private extension SceneControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: SceneUsecaseMock = .init()) -> SceneController {
        withDependencies {
            $0[SceneUsecaseKey.self] = usecase
        } operation: {
            SceneController()
        }
    }
}
