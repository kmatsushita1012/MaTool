import Dependencies
import Shared
import Testing
@testable import Backend

struct SceneControllerTest {
    @Test
    func launchFestival_withFestivalId_returnsPack() async throws {
        let expected = LaunchFestivalPack.mock(festival: .mock(id: "festival-1"))
        var capturedFestivalId: String?
        var capturedUser: UserRole?

        let mock = SceneUsecaseMock(
            fetchLaunchFestivalByFestivalIdHandler: { festivalId, user, _ in
                capturedFestivalId = festivalId
                capturedUser = user
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
        #expect(capturedFestivalId == "festival-1")
        #expect(capturedUser == .guest)
        #expect(mock.fetchLaunchFestivalByFestivalIdCallCount == 1)
    }
}

private extension SceneControllerTest {
    var next: Handler {
        { _ in throw TestError.intentional }
    }

    func make(usecase: SceneUsecaseMock) -> SceneController {
        withDependencies {
            $0[SceneUsecaseKey.self] = usecase
        } operation: {
            SceneController()
        }
    }
}
