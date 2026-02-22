import Dependencies
import Shared
import Testing
@testable import Backend

struct SceneControllerTest {
    @Test
    func launchFestival_正常_festivalId指定() async throws {
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
    func launchFestival_正常_districtId指定() async throws {
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
    func launchFestival_異常_パラメータ不足() async {
        let subject = make()
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

    @Test
    func launchDistrict_異常_ユースケースエラー透過() async {
        let mock = SceneUsecaseMock(fetchLaunchDistrictHandler: { _, _, _ in throw TestError.intentional })
        let subject = make(usecase: mock)
        let request = Application.Request.make(
            method: .get,
            path: "/districts/district-1/launch",
            parameters: ["districtId": "district-1"]
        )

        await #expect(throws: TestError.intentional) {
            _ = try await subject.launchDistrict(request, next: next)
        }
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
